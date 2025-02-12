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
      inherit (inputs.nixpkgs) lib;
      inherit (lib.attrsets) genAttrs;
      cudaLib = import ./cuda-lib { inherit lib; };
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
        inherit cudaLib;
        overlays.default = import ./overlay.nix;
        # NOTE: Unlike other flake attributes, hydraJobs is indexed by jobset name and *then* system name.
        hydraJobs = import ./hydraJobs.nix {
          inherit cudaLib lib nixpkgsInstances;
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
