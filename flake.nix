{
  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    # Use the commit which unbreaks CURL until a release is cut with this:
    # https://github.com/NixOS/nixpkgs/commit/fedcf60ab5d92acee4a205613ef61c318cd69f5b
    nixpkgs.url = "github:NixOS/nixpkgs/7a56cc79c6514a5a6ea283745d6f1bf0f8c8166f";
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
        optionalAttrs
        recurseIntoAttrs
        ;
      inherit (inputs.flake-parts.lib) mkFlake;
      lib = import ./lib { inherit (inputs.nixpkgs) lib; };
      inherit (lib.cuda.utils) flattenDrvTree;
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
        cuda-lib = lib.cuda;
        upstreamable-lib = lib.upstreamable;
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

          checks = flattenDrvTree (recurseIntoAttrs {
            pkgsCuda = recurseIntoAttrs (
              {
                # 8.9 supported by all versions of CUDA 12
                sm_89 = recurseIntoAttrs {
                  cudaPackages_12_2_2 = recurseIntoAttrs pkgs.pkgsCuda.sm_89.cudaPackages_12_2_2;
                  cudaPackages_12_6_3 = recurseIntoAttrs pkgs.pkgsCuda.sm_89.cudaPackages_12_6_3;
                };
              }
              // optionalAttrs (pkgs.stdenv.hostPlatform.system == "aarch64-linux") {
                # Xavier (7.2) is only supported up to CUDA 12.2.2 by cuda-compat on JetPack 5.
                # Unfortunately, NVIDIA isn't releasing support for Xavier on JetPack 6, so we're stuck.
                sm_72 = recurseIntoAttrs {
                  cudaPackages_12_2_2 = recurseIntoAttrs pkgs.pkgsCuda.sm_72.cudaPackages_12_2_2;
                };
                # Orin (8.7) is only supported up to CUDA 12.2.2 by cuda-compat on JetPack 5.
                # Orin has a JetPack 6 release which allows it to run later versions of CUDA, but it has not yet been
                # packaged by https://github.com/anduril/jetpack-nixos.
                sm_87 = recurseIntoAttrs {
                  cudaPackages_12_2_2 = recurseIntoAttrs pkgs.pkgsCuda.sm_87.cudaPackages_12_2_2;
                };
              }
            );
          });

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.treefmt.build.devShell;
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
                  "cuda-packages/wip/"
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
