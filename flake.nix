{
  inputs = {
    flake-parts = {
      inputs.nixpkgs-lib.follows = "nixpkgs";
      url = "github:hercules-ci/flake-parts";
    };
    nixpkgs.url = "github:NixOS/nixpkgs";
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
      mkNixpkgs =
        system:
        import inputs.nixpkgs {
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
      nixpkgsInstances = genAttrs systems mkNixpkgs;
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
        # But I don't care, because it builds things recursively and for eval with `nix-eval-jobs` I can use
        # --force-recurse since I've made sure the jobset is not recursive.
        hydraJobs = {
          x86_64-linux =
            let
              inherit (nixpkgsInstances.x86_64-linux) pkgsCuda;
            in
            {
              # 8.9 supported by all versions of CUDA 12
              sm_89 = mkHydraJobsRecurseByDefault {
                inherit (pkgsCuda.sm_89) cudaPackages_12_2_2 cudaPackages_12_6_3;
              };
            };
          aarch64-linux =
            let
              inherit (nixpkgsInstances.aarch64-linux) pkgsCuda;
            in
            {
              # Xavier (7.2) is only supported up to CUDA 12.2.2 by cuda-compat on JetPack 5.
              # Unfortunately, NVIDIA isn't releasing support for Xavier on JetPack 6, so we're stuck.
              sm_72 = mkHydraJobsRecurseByDefault {
                inherit (pkgsCuda.sm_72) cudaPackages_12_2_2;
              };
              # Orin (8.7) is only supported up to CUDA 12.2.2 by cuda-compat on JetPack 5.
              # Orin has a JetPack 6 release which allows it to run later versions of CUDA, but it has not yet been
              # packaged by https://github.com/anduril/jetpack-nixos.
              sm_87 = mkHydraJobsRecurseByDefault {
                inherit (pkgsCuda.sm_87) cudaPackages_12_2_2;
              };
            };
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
          _module.args.pkgs = nixpkgsInstances.${system};

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
