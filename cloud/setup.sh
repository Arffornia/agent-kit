#!/bin/bash
# portability: linux-only (runs as root in the Ubuntu cloud VM; see docs/SETUP.md for macOS)
# Arffornia cloud environment setup script (Claude Code on the web / cloud sessions).
# Paste it into the environment's "Setup script" box (or "Choose file"). It runs as root on
# Ubuntu 24.04 before Claude Code starts; when it finishes in under ~5 minutes the filesystem is
# snapshotted and reused, so later sessions start with every toolchain and cache already warm.
#
# What it does (all optional, all idempotent, never fails the session):
#   - checks the pre-installed JDK 21, PHP + Composer, Node 22 (adds what is missing); installs
#     and selects PHP $PHP_VERSION (default 8.5, what Arffornia_Website's composer.json requires)
#   - apt: shellcheck, yamllint, bubblewrap + socat (Claude Code sandbox on Linux)
#   - helm + kustomize (pinned versions), noodle (from source, needs Go), mkdocs (docs)
#   - warms the Gradle cache (Arffornia_Mods, Arffornia_Proxy), the Composer cache
#     (Arffornia_Website) and the npm cache (launcher, Nexus libs, Provisioning) from shallow
#     clones of the public repos in /opt/arffornia/warm (sessions use their own clone)
# The environment's variables are NOT set while this runs: edit the defaults below instead.

# ----- settings (edit here) --------------------------------------------------------------
WARM="${WARM:-mod proxy website launcher libs provisioning docs}"   # caches to warm
TOOLS="${TOOLS:-apt helm kustomize mkdocs noodle}"                # extra tools (add: drawio)
PHP_VERSION="${PHP_VERSION:-8.5}"     # website PHP (Laravel 13, composer.json "php": "^8.5"); "" = keep the VM's PHP
PHP_EXTRA="${PHP_EXTRA:-}"            # optional second PHP to install alongside, e.g. "8.4" (not selected)
HELM_VERSION="${HELM_VERSION:-v3.19.0}"
KUSTOMIZE_VERSION="${KUSTOMIZE_VERSION:-v5.7.1}"
BUDGET="${BUDGET:-270}"               # seconds; stay under ~5 min so the snapshot is cached
BIN_DIR="${BIN_DIR:-/usr/local/bin}"
ORG_URL="https://github.com/Arffornia"
WARM_DIR="${WARM_DIR:-/opt/arffornia/warm}"
LOG="${LOG:-/var/log/arffornia-setup.log}"
# -----------------------------------------------------------------------------------------

set -uo pipefail
mkdir -p "$WARM_DIR" "$BIN_DIR"
exec > >(tee -a "$LOG") 2>&1
start=$(date +%s)
log()  { printf '[arffornia-setup %3ss] %s\n' "$(( $(date +%s) - start ))" "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }
want() { case " $2 " in *" $1 "*) return 0;; esac; return 1; }
left() { echo $(( BUDGET - ($(date +%s) - start) )); }
# bounded <seconds> <cmd...>: run with a deadline that never exceeds the remaining budget
bounded() { local t="$1"; shift; local l; l=$(left); [ "$l" -lt "$t" ] && t="$l"; [ "$t" -le 5 ] && { log "skip (budget): $*"; return 1; }; timeout "$t" "$@"; }

# shallow clone or fast-forward a public repo into $WARM_DIR/<name>
fetch_repo() { # <repo> <name>
  local d="$WARM_DIR/$2"
  if [ -d "$d/.git" ]; then bounded 60 git -C "$d" pull -q --ff-only --depth 1 || true
  else bounded 90 git clone -q --depth 1 "$ORG_URL/$1.git" "$d" || return 1; fi
}

# ----- 0. small-machine defaults for Gradle (no secrets in this file) ---------------------
mkdir -p "$HOME/.gradle"
if [ ! -f "$HOME/.gradle/gradle.properties" ]; then
  printf 'org.gradle.jvmargs=-Xmx2g\norg.gradle.daemon=false\norg.gradle.caching=true\n' > "$HOME/.gradle/gradle.properties"
fi

# ----- 1. system packages ----------------------------------------------------------------
job_apt() {
  want apt "$TOOLS" || return 0
  local pkgs=""
  for p in shellcheck yamllint bubblewrap socat make unzip; do
    dpkg -s "$p" >/dev/null 2>&1 || pkgs="$pkgs $p"
  done
  have java     || pkgs="$pkgs openjdk-21-jdk-headless"
  local v ppa=0
  for v in $PHP_VERSION $PHP_EXTRA; do
    have "php$v" && continue
    [ "$ppa" = 1 ] || { bounded 60 add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1 || log "PPA ondrej/php unavailable (PHP $v)"; ppa=1; }
    pkgs="$pkgs php$v-cli php$v-xml php$v-mbstring php$v-curl php$v-sqlite3 php$v-pgsql php$v-zip php$v-intl php$v-bcmath"
  done
  [ -z "$PHP_VERSION" ] && ! have php && pkgs="$pkgs php-cli php-xml php-mbstring php-curl php-sqlite3 php-pgsql php-zip"
  if want drawio "$TOOLS"; then pkgs="$pkgs xvfb libgbm1 libasound2t64"; fi
  [ -n "$pkgs" ] || { log "apt: nothing to install"; return 0; }
  log "apt install:$pkgs"
  export DEBIAN_FRONTEND=noninteractive
  bounded 60 apt-get update -qq || true
  # shellcheck disable=SC2086
  bounded 150 apt-get install -y -qq --no-install-recommends $pkgs >/dev/null || log "apt: some packages failed"
  if [ -n "$PHP_VERSION" ] && [ -x "/usr/bin/php$PHP_VERSION" ]; then
    update-alternatives --set php "/usr/bin/php$PHP_VERSION" >/dev/null 2>&1 || log "could not select PHP $PHP_VERSION"
    log "php: $(php -r 'echo PHP_VERSION;' 2>/dev/null || echo '?') selected"
  fi
  have composer || { bounded 60 bash -c "curl -fsSL https://getcomposer.org/installer | php -- --install-dir='$BIN_DIR' --filename=composer" || true; }
}

# ----- 2. CLI tools ----------------------------------------------------------------------
job_tools() {
  if want helm "$TOOLS" && ! have helm && [ ! -x "$BIN_DIR/helm" ]; then
    log "helm $HELM_VERSION"
    bounded 60 bash -c "curl -fsSL --max-time 50 https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz | tar -xz -C /tmp linux-amd64/helm && install /tmp/linux-amd64/helm '$BIN_DIR/helm'" \
      || log "helm download failed (is get.helm.sh allowed in the network settings?)"
  fi
  if want kustomize "$TOOLS" && ! have kustomize && [ ! -x "$BIN_DIR/kustomize" ]; then
    log "kustomize $KUSTOMIZE_VERSION"
    bounded 60 bash -c "curl -fsSL --max-time 50 https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz | tar -xz -C '$BIN_DIR' kustomize" \
      || log "kustomize download failed"
  fi
  if want noodle "$TOOLS" && ! have noodle && have go; then
    log "noodle (go install)"
    GOBIN="$BIN_DIR" bounded 150 go install github.com/TheGostsniperfr/Noodle/cmd/noodle@latest || log "noodle build failed"
  fi
  if want drawio "$TOOLS" && ! have drawio; then
    log "draw.io desktop (large download)"
    local u
    u="$(bounded 20 curl -fsSL https://api.github.com/repos/jgraph/drawio-desktop/releases/latest | grep -oE 'https://[^"]+amd64[^"]*\.deb' | head -1)"
    [ -n "$u" ] && bounded 120 bash -c "curl -fsSL -o /tmp/drawio.deb '$u' && apt-get install -y -qq /tmp/drawio.deb >/dev/null" || log "drawio install failed"
  fi
}

# ----- 3. caches -------------------------------------------------------------------------
job_gradle() { # sequential on purpose: one Gradle build at a time
  local name repo
  for name in proxy mod; do
    want "$name" "$WARM" || continue
    case "$name" in mod) repo=Arffornia_Mods ;; proxy) repo=Arffornia_Proxy ;; esac
    fetch_repo "$repo" "$name" || { log "clone $repo failed"; continue; }
    local head; head="$(git -C "$WARM_DIR/$name" rev-parse HEAD)"
    [ "$(cat "$WARM_DIR/$name.done" 2>/dev/null)" = "$head" ] && { log "gradle $name: warm"; continue; }
    log "gradle $name: wrapper + dependencies"
    # `dependencies` downloads the wrapper distribution and resolves every configuration;
    # for the mod, compileJava also runs the NeoForge/Minecraft setup (the slow part).
    ( cd "$WARM_DIR/$name" && bounded 200 bash ./gradlew -q --no-daemon -Dorg.gradle.jvmargs=-Xmx2g dependencies \
      && { [ "$name" != mod ] || bounded 200 bash ./gradlew -q --no-daemon -Dorg.gradle.jvmargs=-Xmx2g compileJava; } ) >"$WARM_DIR/$name.log" 2>&1 \
      && echo "$head" > "$WARM_DIR/$name.done" || log "gradle $name: partial (cache kept, the first build finishes it)"
  done
}

job_composer() {
  want website "$WARM" || return 0
  have composer || return 0
  fetch_repo Arffornia_Website website || return 0
  local key; key="$(sha1sum "$WARM_DIR/website/composer.lock" 2>/dev/null | cut -c1-40)"
  [ -n "$key" ] && [ "$(cat "$WARM_DIR/website.done" 2>/dev/null)" = "$key" ] && { log "composer: warm"; return 0; }
  log "composer cache (website)"
  ( cd "$WARM_DIR/website" && COMPOSER_ALLOW_SUPERUSER=1 bounded 150 composer install -q --no-interaction --no-scripts --no-autoloader --ignore-platform-reqs ) >"$WARM_DIR/website.log" 2>&1 \
    && echo "$key" > "$WARM_DIR/website.done" || log "composer warm-up partial (see $WARM_DIR/website.log)"
}

job_npm() {
  local name repo
  for name in launcher libs provisioning docs; do
    want "$name" "$WARM" || continue
    case "$name" in
      launcher) set -- Arffornia_Launcher_V.5.2 ;;
      libs) set -- Nexus_Java Nexus_Logger Nexus_Saver Nexus_Mods ;;
      provisioning) set -- Arffornia_Provisioning ;;
      docs) set -- docs ;;
    esac
    for repo in "$@"; do
      fetch_repo "$repo" "$repo" || { log "clone $repo failed"; continue; }
      local key; key="$(cat "$WARM_DIR/$repo/package-lock.json" "$WARM_DIR/$repo/package.json" 2>/dev/null | sha1sum | cut -c1-40)"
      if [ -f "$WARM_DIR/$repo/package.json" ] && [ "$(cat "$WARM_DIR/$repo.done" 2>/dev/null)" = "$key" ]; then
        log "npm $repo: warm"
      elif [ -f "$WARM_DIR/$repo/package.json" ]; then
        log "npm cache ($repo)"
        ( cd "$WARM_DIR/$repo" && if [ -f package-lock.json ]; then bounded 120 npm ci -s --ignore-scripts --no-audit --no-fund; else bounded 120 npm install -s --ignore-scripts --no-audit --no-fund; fi ) >"$WARM_DIR/$repo.log" 2>&1 \
          && echo "$key" > "$WARM_DIR/$repo.done" || log "npm warm-up partial ($repo, see $WARM_DIR/$repo.log)"
      fi
      if [ -f "$WARM_DIR/$repo/requirements.txt" ] && want mkdocs "$TOOLS"; then
        log "pip (mkdocs) from $repo/requirements.txt"
        bounded 90 python3 -m pip install -q --break-system-packages -r "$WARM_DIR/$repo/requirements.txt" >/dev/null 2>&1 \
          || bounded 90 python3 -m pip install -q -r "$WARM_DIR/$repo/requirements.txt" >/dev/null 2>&1 || log "pip failed"
      fi
    done
  done
}

# ----- run (independent jobs in parallel, each bounded by the budget) ---------------------
log "start (budget ${BUDGET}s; log in $LOG)"
job_apt & a=$!
job_tools & b=$!
job_gradle & c=$!
job_composer & d=$!
job_npm & e=$!
wait $a $b $c $d $e

log "versions:"
for c in java php composer node npm gradle helm kustomize noodle mkdocs shellcheck gh; do
  have "$c" || continue
  v="$($c --version 2>/dev/null | head -1)"; [ -n "$v" ] || v="$($c version 2>/dev/null | head -1)"
  printf '  %-11s %s\n' "$c" "${v:-installed}"
done
log "done in $(( $(date +%s) - start ))s"
exit 0
