# macOS (Apple Silicon or Intel) toolchain for agent-kit and the Arffornia repos.
#   brew bundle --file=Brewfile          (from an agent-kit checkout)
# Kit and hooks: git, jq (built into macOS 15+, listed for older systems), gh, shellcheck.
brew "git"
brew "jq"
brew "gh"
brew "shellcheck"
brew "actionlint"
brew "yamllint"
brew "python@3.13"
brew "coreutils"        # optional: gtimeout etc.; the hooks do not need it
# Arffornia stacks
brew "node@22"          # launcher, Nexus_* libs, Provisioning, the claude CLI (npm i -g @anthropic-ai/claude-code)
brew "php"              # website: Homebrew's php is the latest release (8.5), as composer.json requires ("^8.5")
brew "composer"
cask "temurin@21"       # mod (NeoForge 1.21.1) and proxy (Velocity)
brew "kustomize"        # infra
brew "helm"
brew "gitleaks"
brew "pre-commit"
