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
        cartesianProduct
        genAttrs
        getAttrs
        mapCartesianProduct
        recurseIntoAttrs
        recursiveUpdate
        ;
      inherit (inputs.nixpkgs.lib.lists) foldl' optionals;
      inherit (inputs.nixpkgs.lib.modules) evalModules;
      inherit (inputs.flake-parts.lib) mkFlake;

      cuda-lib = import ./cuda-lib { inherit (inputs.nixpkgs) lib; };
      inherit (cuda-lib.utils) flattenDrvTree;
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
        inherit cuda-lib;
        overlays.default = import ./overlay.nix;
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = import inputs.nixpkgs {
            inherit system;
            # TODO: Due to the way Nixpkgs is built in stages, the config attribute set is not re-evaluated.
            # This is problematic for us because we use it to signal the CUDA capabilities to the overlay.
            # The only way I've found to combat this is to use pkgs.extend, which is not ideal.
            # TODO: This also means that Nixpkgs needs to be imported *with* the correct config attribute set
            # from the start, unless they're willing to re-import Nixpkgs with the correct config.
            config = {
              allowUnfree = true;
              cudaSupport = true;
            };
            overlays = [ inputs.self.overlays.default ];
          };

          checks =
            let
              tree =
                genAttrs
                  (
                    [
                      "sm_89"
                    ]
                    ++ optionals (pkgs.stdenv.hostPlatform.system == "aarch64-linux") [
                      "sm_72"
                      "sm_87"
                    ]
                  )
                  (
                    realArchitecture:
                    recurseIntoAttrs (
                      getAttrs [
                        "cudaPackages_11"
                        "cudaPackages_12"
                      ] pkgs.pkgsCuda.${realArchitecture}
                    )
                  );
            in
            flattenDrvTree (recurseIntoAttrs tree);

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.devShells.cuda-redist;
          };

          legacyPackages = pkgs;

          packages = {
            default = config.packages.cuda-redist;
            cuda-redist = pkgs.python311Packages.callPackage ./scripts/cuda-redist { };
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
