# NOTE: This derivation is meant only for Jetsons.
# Links were retrieved from https://repo.download.nvidia.com/jetson.
{
  backendStdenv,
  callPackage,
  config,
  cuda_cudart,
  cuda-lib,
  cudaMajorMinorVersion,
  cudnn,
  libcublas,
  libcudla,
}:
let
  hostRedistArch = cuda-lib.utils.getRedistArch (
    config.data.jetsonTargets != [ ]
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
        cudaArchitectures = [
          "sm_53"
          "sm_62"
          "sm_70"
          "sm_72"
          "sm_80"
          "sm_87"
        ];
        outputs = [
          "out"
          "dev"
          "include"
          "lib"
          "static"
          "sample"
        ];
      };
      recursiveHash = builtins.throw "`recursiveHash` should never be required by redist-builder";
    };
    packageName = "tensorrt";
    releaseInfo = {
      license = "TensorRT";
      licensePath = null;
      name = "NVIDIA TensorRT";
      version = "8.5.2.2";
    };
  };

  debBuilderArgs = {
    manifestMajorMinorVersion = "35.6";
    sourceName = "tensorrt";
    postDebUnpack = ''
      for dir in include lib; do
        mv "$sourceRoot/usr/$dir/aarch64-linux-gnu" "$sourceRoot/$dir"
      done

      mv "$sourceRoot/usr/src/tensorrt" "$sourceRoot/samples"
      rm -rf "$sourceRoot/usr"
    '';
    srcIsNull = hostRedistArchIsUnsupported || cudaVersionIsUnsupported;
    overrideAttrsFn = prevAttrs: {
      # Samples, lib, and static all reference a FHS
      allowFHSReferences = true;
      brokenConditions = prevAttrs.brokenConditions // {
        "CUDA version mismatch" = cudaVersionIsUnsupported;
      };
      badPlatformsConditions = prevAttrs.badPlatformsConditions // {
        "TensorRT ${redistBuilderArgs.releaseInfo.version} is only available for Jetson devices" =
          hostRedistArchIsUnsupported;
      };
      buildInputs = prevAttrs.buildInputs or [ ] ++ [
        cuda_cudart
        cudnn
        libcublas
        libcudla
      ];
      autoPatchelfIgnoreMissingDeps = prevAttrs.autoPatchelfIgnoreMissingDeps ++ [
        "libnvdla_compiler.so"
      ];
      passthru = prevAttrs.passthru // {
        inherit cudnn;
      };
      meta = prevAttrs.meta // {
        platforms = prevAttrs.meta.platforms or [ ] ++ [ "aarch64-linux" ];
      };
    };
  };
in
callPackage ../deb-builder (redistBuilderArgs // debBuilderArgs)
