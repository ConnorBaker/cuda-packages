{
  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs.url = "github:nixos/nixpkgs";
    git-hooks-nix = {
      inputs = {
        nixpkgs-stable.follows = "nixpkgs";
        nixpkgs.follows = "nixpkgs";
      };
      url = "github:cachix/git-hooks.nix";
    };
    treefmt-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
      url = "github:numtide/treefmt-nix";
    };
  };

  nixConfig = {
    extra-substituters = [ "https://cuda-maintainers.cachix.org" ];
    extra-trusted-substituters = [ "https://cuda-maintainers.cachix.org" ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];
      perSystem =
        { config, pkgs, ... }:
        {
          devShells = {
            default = config.devShells.cuda-redist;
            cuda-redist = config.packages.cuda-redist;
          };

          packages = {
            default = config.packages.cuda-redist;
            cuda-redist = pkgs.python311Packages.callPackage ./redist/scripts/cuda-redist { };
          };

          pre-commit.settings.hooks = {
            # Formatter checks
            treefmt = {
              enable = true;
              package = config.treefmt.build.wrapper;
            };

            # Nix checks
            deadnix.enable = true;
            nil.enable = true;
            statix.enable = true;

            # Python checks
            pyright = {
              enable = true;
              settings.binPath =
                let
                  # We need to provide wrapped version of mypy and pyright which can find our imports.
                  # TODO: The script we're sourcing is an implementation detail of `mkShell` and we should
                  # not depend on it exisitng. In fact, the first few lines of the file state as much
                  # (that's why we need to strip them, sourcing only the content of the script).
                  wrapper =
                    name:
                    pkgs.writeShellScript name ''
                      source <(sed -n '/^declare/,$p' ${config.devShells.cuda-redist})
                      ${name} "$@"
                    '';
                in
                "${wrapper "pyright"}";
            };
            ruff.enable = true; # Ruff both lints and checks sorted imports
          };

          treefmt = {
            projectRootFile = "flake.nix";
            programs = {
              # Markdown, YAML
              # JSON is not formatted; it should not be modified because it is either vendored from NVIDIA or
              # produced by a script.
              prettier = {
                enable = true;
                includes = [
                  "*.md"
                  "*.yaml"
                ];
                excludes = [ "redist/data/*/**.json" ];
                settings = {
                  embeddedLanguageFormatting = "auto";
                  printWidth = 120;
                  tabWidth = 2;
                };
              };

              # Nix
              nixfmt.enable = true;

              # Python
              ruff.enable = true;

              # Shell
              shellcheck.enable = true;
              shfmt.enable = true;
            };
          };
        };
    };
}
