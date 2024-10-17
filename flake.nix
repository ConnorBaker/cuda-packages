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
    let
      inherit (inputs.nixpkgs.lib)
        evalModules
        filterAttrs
        isDerivation
        mapAttrs'
        optionalAttrs
        ;
      inherit (inputs.flake-parts.lib) mkFlake;

      # Utility function
      mkOverlay =
        {
          capabilities,
          hostCompiler ? "gcc",
        }:
        (evalModules {
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
    mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];

      flake = {
        inherit mkOverlay;
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          xavierPkgs = pkgs.extend (mkOverlay {
            capabilities = [ "7.2" ];
          });
          orinPkgs = pkgs.extend (mkOverlay {
            capabilities = [ "8.7" ];
          });
          adaOverlay = mkOverlay { capabilities = [ "8.9" ]; };
        in
        {
          # Make our package set the default.
          _module.args = {
            pkgs = import inputs.nixpkgs {
              inherit system;
              # Unfree needs to be set in the initial config attribute set, even though we override it in our overlay.
              config.allowUnfree = true;
              # Default to Ada
              overlays = [ adaOverlay ];
            };
          };

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.devShells.cuda-redist;
          };

          legacyPackages =
            # pkgs is by default adaPkgs
            pkgs
            // {
              allDrvs = pkgs.cudaPackages.cuda-lib.utils.flattenDrvTree pkgs;
              cudaPackagesDrvs = pkgs.cudaPackages.cuda-lib.utils.flattenDrvTree pkgs.cudaPackages;
            }
            // optionalAttrs (system == "aarch64-linux") {
              xavier = xavierPkgs;
              orin = orinPkgs;
            };

          packages =
            let
              inherit (pkgs) linkFarm python311Packages;
              # NOTE: Computing the `outPath` is the easiest way to check if evaluation will fail for some reason.
              # Originally, I used meta.available, but that field isn't produced by recursively checking dependents by
              # default, and requires an undocumented config option (checkMetaRecursively) to do so:
              # https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/check-meta.nix#L496
              # What we really need is something like:
              # https://github.com/NixOS/nixpkgs/pull/245322
              filterForTopLevelPackages = filterAttrs (
                _: value:
                let
                  attempt = isDerivation value && value.outPath or null != null;
                  tried = builtins.tryEval (builtins.deepSeq attempt attempt);
                in
                tried.success && tried.value
              );
              mkFlattenedFiltered =
                cudaPackages:
                let
                  # Manually raise and flatten the few nested attributes we have which contain derivations.
                  raised = mapAttrs' (name: value: {
                    name = "cuda-library-samples-${name}";
                    inherit value;
                  }) cudaPackages.cuda-library-samples;
                in
                filterForTopLevelPackages (cudaPackages // raised);
            in
            {
              default = config.packages.cuda-redist;
              cuda-redist = python311Packages.callPackage ./scripts/cuda-redist { };
              cudaPackages_11 = linkFarm "cudaPackages_11" (mkFlattenedFiltered pkgs.cudaPackages_11);
              cudaPackages_12 = linkFarm "cudaPackages_12" (mkFlattenedFiltered pkgs.cudaPackages_12);
            }
            // optionalAttrs (system == "aarch64-linux") {
              cudaPackages_11-xavier = linkFarm "cudaPackages_11-xavier" (
                mkFlattenedFiltered xavierPkgs.cudaPackages_11
              );
              cudaPackages_12-xavier = linkFarm "cudaPackages_12-xavier" (
                mkFlattenedFiltered xavierPkgs.cudaPackages_12
              );
              cudaPackages_11-orin = linkFarm "cudaPackages_11-orin" (
                mkFlattenedFiltered orinPkgs.cudaPackages_11
              );
              cudaPackages_12-orin = linkFarm "cudaPackages_12-orin" (
                mkFlattenedFiltered orinPkgs.cudaPackages_12
              );
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
