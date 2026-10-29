# Machine setup: macOS, Linux, NixOS

Everything agent-kit ships (hooks, `scripts/init`, Makefile snippets, `codex/sync-skills.sh`)
runs on **macOS arm64 (Apple Silicon)** and **Linux x86_64 / arm64**. The only Linux-only file is
`cloud/setup.sh`, which runs as root inside Anthropic's Ubuntu cloud VM.

## What "portable" means here

macOS ships **bash 3.2** (`/bin/bash`, GPLv2) and **BSD** `sed`, `grep`, `date`, `stat`. The kit
stays compatible with them instead of requiring GNU tools:

| Trap | Rule in this repo |
|---|---|
| `declare -A`, `mapfile`, `${var,,}`, `\|&`, `&>>` (bash 4+) | not used; `tests/portability.sh` fails on them |
| `sed -i 's/…/'` (GNU only) | `sed -i.bak '…' f && rm -f f.bak` |
| `stat -c`, `date -d`, `readlink -f`, `grep -P`, `timeout` | BSD fallback on the same line, or `with_timeout` from `lib.sh` (uses `timeout`, then `gtimeout`, then a watcher process) |
| `case` patterns inside `$( … )` | written `(pattern)` with a leading parenthesis (bash 3.2 parse bug) |

CI (`.github/workflows/ci.yml`) runs the hook suite on `ubuntu-latest`, `ubuntu-24.04-arm` and
`macos-latest` with macOS's own `/bin/bash` 3.2 first in `PATH`, and the portability lint on
every shell script. Run both locally before changing a script:

```bash
bash plugins/arffornia/scripts/tests/run.sh
bash plugins/arffornia/scripts/tests/portability.sh
```

## macOS with Homebrew

```bash
xcode-select --install                       # git, make, clang (once)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone https://github.com/Arffornia/agent-kit.git ~/src/agent-kit
brew bundle --file=~/src/agent-kit/Brewfile  # kit tools + every Arffornia stack
echo 'export PATH="/opt/homebrew/opt/node@22/bin:$PATH"' >> ~/.zprofile   # node@22 is keg-only
npm install -g @anthropic-ai/claude-code     # then: claude, /login with your claude.ai account
```

Then, in each Arffornia repo: `scripts/init` (it prints the `brew install …` line for anything
missing). Notes for Apple Silicon:

- Java: `temurin@21` is a native arm64 JDK; Gradle and NeoForge run natively. The Minecraft
  client (`runClient`) downloads arm64 LWJGL natives on 1.21.1.
- The launcher: `npm ci` fetches arm64 Electron; electron-builder makes `arm64` DMGs by default
  (`--x64` for Intel builds).
- PHP: Homebrew's `php` is the current release (8.4+), which the website's `composer.lock` needs.
- The sandbox uses macOS Seatbelt, built in: nothing to install. Git over SSH does not work
  inside it; use HTTPS remotes (`gh auth setup-git`).

## Nix (NixOS, nix-darwin, or nix on any Linux/macOS)

agent-kit has a `flake.nix` with two dev shells for `x86_64-linux`, `aarch64-linux`,
`aarch64-darwin` and `x86_64-darwin`:

```bash
nix develop github:Arffornia/agent-kit          # kit tools: bash 5, git, jq, gh, shellcheck, actionlint, python3 + PyYAML, node 22
nix develop github:Arffornia/agent-kit#full     # + JDK 21 (Temurin), PHP 8.4 + Composer, kustomize, helm, gitleaks, pre-commit
```

Product repos do not need their own flake: run `nix develop github:Arffornia/agent-kit#full`
from the repo, then `scripts/init`. With **direnv**, put `use flake github:Arffornia/agent-kit#full`
in the repo's `.envrc` (not committed unless the repo adopts it).

**Dotfiles (NixOS or nix-darwin + home-manager)**: add the kit as a flake input and take the
packages from the shell, so the same toolchain is on your `PATH` everywhere:

```nix
# flake.nix of your dotfiles
inputs.agent-kit.url = "github:Arffornia/agent-kit";
# in a home-manager module (pkgs.system is aarch64-darwin on the Mac, x86_64-linux on NixOS)
home.packages = inputs.agent-kit.devShells.${pkgs.system}.full.nativeBuildInputs;
```

On nix-darwin, Claude Code itself can come from nixpkgs (`claude-code`) or npm. Keep
`/bin/bash` untouched: the hooks are tested against it, and a nix bash 5 earlier in `PATH` is
also fine.

The flake pins nixpkgs `nixos-26.05` through the channel tarball
(`https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz`) and a `flake.lock`; `nix flake
update` moves it.

## Linux (Debian/Ubuntu)

```bash
sudo apt install git make jq shellcheck python3-yaml bubblewrap socat   # bubblewrap + socat: Claude Code sandbox
# gh: https://github.com/cli/cli/blob/trunk/docs/install_linux.md ; node 22: https://nodejs.org or nvm
```

Ubuntu 24.04+ may block bubblewrap's user namespaces through AppArmor; the
[sandboxing docs](https://code.claude.com/docs/en/sandboxing) give the profile to add.

## Claude Code on every machine

- Sign in with your claude.ai account (`/login`). No API key is needed anywhere: the in-session
  review, the hooks and the scheduled tasks all run under that login.
- Install the plugin once: `/plugin marketplace add Arffornia/agent-kit`, then
  `/plugin install arffornia@agent-kit`. Repos that adopted the templates enable it for you.
- Codex or OpenCode: `../agent-kit/codex/sync-skills.sh` exposes the same skills through
  `.agents/skills/`.

## Not verified yet

The macOS paths above were checked against the tools' docs and by the macOS CI job (bash 3.2,
BSD tools, Apple Silicon runner) for the hooks; `brew bundle`, the full nix shell on
`aarch64-darwin` (it evaluates; it was not built on a Mac) and a full Gradle/Electron build on a
Mac still need a first run on Brian's machine.
