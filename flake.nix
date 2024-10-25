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
      inherit (inputs.nixpkgs.lib.attrsets)
        mapAttrs
        optionalAttrs
        recurseIntoAttrs
        ;
      inherit (inputs.nixpkgs.lib.modules)
        evalModules
        ;
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
        {
          config,
          pkgs,
          system,
          ...
        }:
        let
          configs =
            {
              ada = "8.9";
            }
            // optionalAttrs (system == "aarch64-linux") {
              orin = "8.7";
              xavier = "7.2";
            };

          ourPkgs = mapAttrs (
            _: capability:
            import inputs.nixpkgs {
              inherit system;
              config = {
                allowUnfree = true;
                cudaSupport = true;
                cudaCapabilities = [ capability ];
              };
              overlays = [
                (mkOverlay { capabilities = [ capability ]; })
              ];
            }
          ) configs;

          ourCudaPackages = mapAttrs (name: _: {
            inherit (ourPkgs.${name}) cudaPackages_11 cudaPackages_12;
          }) configs;
        in
        {
          _module.args.pkgs = ourPkgs.ada;

          checks = flattenDrvTree (recurseIntoAttrs (mapAttrs (_: recurseIntoAttrs) ourCudaPackages));

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.devShells.cuda-redist;
          };

          legacyPackages = ourPkgs // {
            # Paths must be relative to the flake root.
            adaCudaPackagesDrvAttrEval = map (
              attrPath:
              cuda-lib.utils.unsafeEvalFlakeDrv ./. (
                [
                  "legacyPackages"
                  system
                  "ada"
                  "cudaPackages"
                ]
                ++ attrPath
              )
            ) (cuda-lib.utils.drvAttrPaths ourPkgs.ada.cudaPackages);
          };

          packages =
            let
              # Use our package set to ensure the CUDA dependencies we pull in come from our repo and not upstream.
              inherit (pkgs.python311Packages) callPackage;
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
