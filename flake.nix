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
        {
          config,
          lib,
          pkgs,
          system,
          ...
        }:
        let
          getOverlay =
            {
              capabilities,
              hostCompiler ? "gcc",
            }:
            (lib.evalModules {
              specialArgs = {
                inherit (inputs) nixpkgs;
              };
              modules = [
                {
                  cuda = {
                    inherit capabilities hostCompiler;
                    forwardCompat = false;
                  };
                }
                ./modules
              ];
            }).config.overlay;
        in
        {
          # Make our package set the default.
          _module.args = {
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Unfree needs to be set in the initial config attribute set, even though we override it in our overlay.
              config.allowUnfree = true;
              overlays = [
                (getOverlay {
                  capabilities = [ "8.9" ];
                })
              ];
            };
          };

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.devShells.cuda-redist;
          };

          legacyPackages =
            let
              getPackageSets = args: {
                inherit (pkgs.extend (getOverlay args)) cudaPackages_11 cudaPackages_12 cudaPackages;
              };
              normalPackageSets = getPackageSets { capabilities = [ "8.9" ]; };
              jetsonPackageSets = {
                xavier = getPackageSets { capabilities = [ "7.2" ]; };
                orin = getPackageSets { capabilities = [ "8.7" ]; };
              };
            in
            normalPackageSets // lib.optionalAttrs (system == "aarch64-linux") jetsonPackageSets;

          packages =
            let
              inherit (lib.attrsets) isAttrs isDerivation filterAttrs;
              inherit (pkgs) linkFarm python311Packages;
              filterForTopLevelPackages = filterAttrs (
                _: value:
                let
                  attempt = isAttrs value && isDerivation value && value.meta.available or false;
                  forcedAttempt = builtins.deepSeq attempt attempt;
                  tried = builtins.tryEval forcedAttempt;
                in
                if tried.success then tried.value else false
              );
            in
            {
              default = config.packages.cuda-redist;
              cuda-redist = python311Packages.callPackage ./scripts/cuda-redist { };
              cudaPackages_11 = linkFarm "cudaPackages_11" (filterForTopLevelPackages pkgs.cudaPackages_11);
              cudaPackages_12 = linkFarm "cudaPackages_12" (filterForTopLevelPackages pkgs.cudaPackages_12);
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
                excludes = [ "**.json" ];
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
