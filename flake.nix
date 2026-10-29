{
  # Dev shells for agent-kit and the Arffornia repos, on Linux (x86_64, arm64) and macOS (Apple Silicon, Intel).
  #   nix develop                                   # kit development: hooks, tests, lint
  #   nix develop github:Arffornia/agent-kit#full   # every Arffornia stack, from any repo, no flake needed there
  # nix-darwin / home-manager users can add `inputs.agent-kit.devShells.${system}.full.nativeBuildInputs`
  # to their packages instead. See docs/SETUP.md.
  description = "Arffornia agent-kit dev shells";

  # Channel tarball: the same content as github:NixOS/nixpkgs/nixos-26.05, fetchable without the GitHub API.
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-26.05/nixexprs.tar.xz";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forAll = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      kitTools = pkgs: with pkgs; [
        bashInteractive git gnumake jq gh shellcheck actionlint yamllint
        (python3.withPackages (ps: [ ps.pyyaml ]))
        nodejs_22 # the claude CLI: npm install -g @anthropic-ai/claude-code
      ];
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = kitTools pkgs;
          shellHook = ''echo "agent-kit shell: bash plugins/arffornia/scripts/tests/run.sh"'';
        };
        full = pkgs.mkShell {
          packages = kitTools pkgs ++ (with pkgs; [
            temurin-bin-21                 # Arffornia_Mods (NeoForge 1.21.1), Arffornia_Proxy (Velocity)
            php84 php84Packages.composer   # Arffornia_Website (composer.lock needs PHP >= 8.4.1)
            kustomize kubernetes-helm      # infra
            gitleaks pre-commit
          ]);
          shellHook = ''
            export GRADLE_OPTS="''${GRADLE_OPTS:--Dorg.gradle.jvmargs=-Xmx2g}"
            echo "Arffornia full shell ($(uname -s)/$(uname -m)): java, php 8.4, composer, node 22, helm, kustomize"
          '';
        };
      });
    };
}
