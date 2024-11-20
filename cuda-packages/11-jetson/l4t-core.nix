# NOTE: This derivation is meant only for Jetsons.
# Links were retrieved from https://repo.download.nvidia.com/jetson.
{
  backendStdenv,
  deb-builder,
  lib,
  cudaMajorMinorVersion,
  expat,
  flags,
  libglvnd,
}:
let
  hostRedistArch = lib.cuda.utils.getRedistArch (
    flags.jetsonTargets != [ ]
  ) backendStdenv.hostPlatform.system;
  hostRedistArchIsUnsupported = hostRedistArch != "linux-aarch64";
  cudaVersionIsUnsupported = cudaMajorMinorVersion != "11.8";

  redistBuilderArgs = {
    libPath = null;
    packageInfo = {
      features = {
        # NOTE: Generated manually by unpacking everything and running
        #   ls -1 ./result-lib/lib/*.so | xargs -I{} sh -c 'cuobjdump {} || true' | grep "arch =" | sort -u
        # and populating the list.
        # cudaArchitectures = [
        # ];
        outputs = [
          "out"
          # "dev"
          # "include"
          # "lib"
          # "static"
        ];
      };
      recursiveHash = builtins.throw "`recursiveHash` should never be required by redist-builder";
    };
    packageName = "l4t-core";
    releaseInfo = {
      license = "tegra";
      licensePath = null;
      name = "NVIDIA CUDA Deep Neural Network library";
      version = "35.6.0";
    };
  };

  debBuilderArgs = {
    manifestMajorMinorVersion = "35.6";
    manifestPackageSet = "t234";
    debName = "nvidia-l4t-core";
    postDebUnpack = ''
      mv "$sourceRoot/usr/lib/aarch64-linux-gnu/tegra" "$sourceRoot/lib"
      rm -rf "$sourceRoot/usr"
      rm -rf "$sourceRoot/etc"
      rm -f "$sourceRoot/lib/ld.so.conf"
    '';
    srcIsNull = hostRedistArchIsUnsupported || cudaVersionIsUnsupported;
    overrideAttrsFn = prevAttrs: {
      brokenConditions = prevAttrs.brokenConditions // {
        "CUDA version mismatch" = cudaVersionIsUnsupported;
      };
      badPlatformsConditions = prevAttrs.badPlatformsConditions // {
        "l4t-core ${redistBuilderArgs.releaseInfo.version} is only available for Jetson devices" =
          hostRedistArchIsUnsupported;
      };
      buildInputs = prevAttrs.buildInputs or [ ] ++ [
        expat
        libglvnd
      ];
      meta = prevAttrs.meta // {
        broken = !flags.isJetsonBuild;
        platforms = [ "aarch64-linux" ];
      };
    };
  };
in
deb-builder (redistBuilderArgs // debBuilderArgs)
