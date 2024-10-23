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

          ourPkgs =
            {
              inherit adaPkgs;
            }
            // optionalAttrs (system == "aarch64-linux") {
              inherit orinPkgs xavierPkgs;
            };

          ourCudaPackages =
            {
              recurseForDerivations = true;
              adaCudaPackages = {
                recurseForDerivations = true;
                inherit (adaPkgs) cudaPackages_11 cudaPackages_12;
              };
            }
            // optionalAttrs (system == "aarch64-linux") {
              orinCudaPackages = {
                recurseForDerivations = true;
                inherit (orinPkgs) cudaPackages_11 cudaPackages_12;
              };
              xavierCudaPackages = {
                recurseForDerivations = true;
                inherit (xavierPkgs) cudaPackages_11 cudaPackages_12;
              };
            };
        in
        {
          # Make upstream's cudaPackages the default.
          _module.args = {
            pkgs = adaPkgs;
          };

          checks = flattenDrvTree { attrs = ourCudaPackages; };

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.devShells.cuda-redist;
          };

          legacyPackages = ourPkgs;

          packages =
            let
              # Use our package set to ensure the CUDA dependencies we pull in come from our repo and not upstream.
              inherit (adaPkgs.python311Packages) callPackage;
            in
            # Actual packages
            {
              default = config.packages.cuda-redist;
              cuda-redist = callPackage ./scripts/cuda-redist { };
            };

          pre-commit.settings.hooks =
            let
              nixToolConfig = {
                enable = true;
                excludes = [
                  "cudaPackages-wip/"
                  "versioned-packages/"
                ];
              };
            in
            {
              # Formatter checks
              treefmt = {
                enable = true;
                inherit (nixToolConfig) excludes;
                package = config.treefmt.build.wrapper;
              };

              # Nix checks
              deadnix = nixToolConfig;
              nil = nixToolConfig;
              statix = nixToolConfig;
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
                excludes = [ "*.json" ];
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
