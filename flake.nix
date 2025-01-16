{
  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
    nixpkgs-24_11.url = "github:NixOS/nixpkgs/release-24.11";
    git-hooks-nix = {
      inputs.nixpkgs.follows = "nixpkgs";
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
      inherit (inputs.flake-parts.lib) mkFlake;
      lib = import ./lib { inherit (inputs.nixpkgs) lib; };
      inherit (lib.attrsets) genAttrs;
      inherit (lib.upstreamable.attrsets) mkHydraJobsRecurseByDefault;
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      # NOTE: Must match the names in inputs
      nixpkgsVersions = [
        "nixpkgs"
        "nixpkgs-24_11"
      ];
      mkNixpkgs =
        nixpkgsVersion: system:
        import inputs.${nixpkgsVersion} {
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
      # Memoization through lambda lifting.
      nixpkgsInstances = genAttrs systems (
        system: genAttrs nixpkgsVersions (nixpkgsVersion: mkNixpkgs nixpkgsVersion system)
      );
    in
    mkFlake { inherit inputs; } {
      inherit systems;

      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.git-hooks-nix.flakeModule
      ];

      flake = {
        cuda-lib = lib.cuda;
        upstreamable-lib = lib.upstreamable;
        overlays.default = import ./overlay.nix;
        # NOTE: Unlike other flake attributes, hydraJobs is indexed by jobset name and *then* system name.
        hydraJobs = {
          # 8.9 supported by all versions of CUDA 12
          sm_89 = genAttrs systems (
            system:
            genAttrs nixpkgsVersions (
              nixpkgsVersion:
              mkHydraJobsRecurseByDefault {
                inherit (nixpkgsInstances.${system}.${nixpkgsVersion}.pkgsCuda.sm_89)
                  cudaPackages_12_2_2
                  cudaPackages_12_6_3
                  ;
              }
            )
          );
          # Xavier (7.2) is only supported up to CUDA 12.2.2 by cuda-compat on JetPack 5.
          # Unfortunately, NVIDIA isn't releasing support for Xavier on JetPack 6, so we're stuck.
          sm_72 = genAttrs [ "aarch64-linux" ] (
            system:
            genAttrs nixpkgsVersions (
              nixpkgsVersion:
              mkHydraJobsRecurseByDefault {
                inherit (nixpkgsInstances.${system}.${nixpkgsVersion}.pkgsCuda.sm_72)
                  cudaPackages_12_2_2
                  ;
              }
            )
          );
          # Orin (8.7) is only supported up to CUDA 12.2.2 by cuda-compat on JetPack 5.
          # Orin has a JetPack 6 release which allows it to run later versions of CUDA, but it has not yet been
          # packaged by https://github.com/anduril/jetpack-nixos.
          sm_87 = genAttrs [ "aarch64-linux" ] (
            system:
            genAttrs nixpkgsVersions (
              nixpkgsVersion:
              mkHydraJobsRecurseByDefault {
                inherit (nixpkgsInstances.${system}.${nixpkgsVersion}.pkgsCuda.sm_87)
                  cudaPackages_12_2_2
                  ;
              }
            )
          );
        };
      };

      perSystem =
        {
          config,
          pkgs,
          system,
          ...
        }:
        {
          _module.args.pkgs = nixpkgsInstances.${system}.nixpkgs;

          devShells = {
            inherit (config.packages) cuda-redist;
            default = config.treefmt.build.devShell;
          };

          legacyPackages = pkgs;

          packages = {
            default = config.packages.cuda-redist;
            cuda-redist = pkgs.python3Packages.callPackage ./scripts/cuda-redist { };
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
