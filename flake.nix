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
      inherit (inputs.nixpkgs.lib) evalModules optionalAttrs;
      inherit (inputs.flake-parts.lib) mkFlake;

      cuda-lib = import ./cuda-lib { inherit (inputs.nixpkgs) lib; };
      inherit (cuda-lib.utils) flattenDrvTree;

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
        inherit cuda-lib mkOverlay;
      };

      perSystem =
        { config, system, ... }:
        let
          adaPkgs = import inputs.nixpkgs {
            inherit system;
            # Unfree needs to be set in the initial config attribute set, even though we override it in our overlay.
            # TODO: Are config attributes not re-evaluated when the overlay changes? Or is it just the Nix flake's CLI
            # which warns when an overlay enables allowUnfree and the first pkgs instantiation doesn't?
            config = {
              allowUnfree = true;
              cudaSupport = true;
              cudaCapabilities = [ "8.9" ];
            };
            overlays = [ (mkOverlay { capabilities = [ "8.9" ]; }) ];
          };
          orinPkgs = adaPkgs.extend (mkOverlay {
            capabilities = [ "8.7" ];
          });
          xavierPkgs = adaPkgs.extend (mkOverlay {
            capabilities = [ "7.2" ];
          });

          # Utility.
          inherit (adaPkgs) linkFarm;
        in
        {
          # Make upstream's cudaPackages the default.
          _module.args = {
            pkgs = adaPkgs;
          };

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.devShells.cuda-redist;
          };

          legacyPackages =
            # Useful attributes to make sure we don't break eval.
            {
              inherit adaPkgs;
              adaCudaPackages11Drvs = linkFarm "adaCudaPackages11Drvs" (flattenDrvTree {
                attrs = adaPkgs.cudaPackages_11;
              });
              adaCudaPackages12Drvs = linkFarm "adaCudaPackages12Drvs" (flattenDrvTree {
                attrs = adaPkgs.cudaPackages_12;
              });
              adaPkgsDrvs = linkFarm "adaPkgsDrvs" (flattenDrvTree {
                attrs = adaPkgs;
              });
            }
            // optionalAttrs (system == "aarch64-linux") {
              inherit orinPkgs;
              orinCudaPackages11Drvs = linkFarm "orinCudaPackages11Drvs" (flattenDrvTree {
                attrs = orinPkgs.cudaPackages_11;
              });
              orinCudaPackages12Drvs = linkFarm "orinCudaPackages12Drvs" (flattenDrvTree {
                attrs = orinPkgs.cudaPackages_12;
              });
              orinPkgsDrvs = linkFarm "orinPkgsDrvs" (flattenDrvTree {
                attrs = orinPkgs;
              });

              inherit xavierPkgs;
              xavierCudaPackages11Drvs = linkFarm "xavierCudaPackages11Drvs" (flattenDrvTree {
                attrs = xavierPkgs.cudaPackages_11;
              });
              xavierCudaPackages12Drvs = linkFarm "xavierCudaPackages12Drvs" (flattenDrvTree {
                attrs = xavierPkgs.cudaPackages_12;
              });
              xavierPkgsDrvs = linkFarm "xavierPkgsDrvs" (flattenDrvTree {
                attrs = xavierPkgs;
              });
            };

          packages =
            let
              # Use our package set to ensure the CUDA dependencies we pull in come from our repo and not upstream.
              inherit (adaPkgs.python311Packages) callPackage;
            in
            # Actual packages
            {
              default = config.packages.cuda-redist;
              cuda-redist = callPackage ./scripts/cuda-redist { };
            }
            # Packages to be checked for eval.
            // {
              inherit (config.legacyPackages) adaCudaPackages11Drvs adaCudaPackages12Drvs;
            }
            // optionalAttrs (system == "aarch64-linux") {
              inherit (config.legacyPackages)
                orinCudaPackages11Drvs
                orinCudaPackages12Drvs
                xavierCudaPackages11Drvs
                xavierCudaPackages12Drvs
                ;
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
