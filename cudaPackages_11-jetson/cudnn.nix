# NOTE: This derivation is meant only for Jetsons.
# Links were retrieved from https://repo.download.nvidia.com/jetson.
{
  backendStdenv,
  callPackage,
  config,
  cuda-lib,
  cudaMajorMinorVersion,
  lib,
  libcublas,
  patchelf,
  zlib,
}:
let
  inherit (lib.meta) getExe;
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
          "sm_61"
          "sm_62"
          "sm_70"
          "sm_72"
          "sm_75"
          "sm_80"
          "sm_86"
          "sm_87"
        ];
        outputs = [
          "out"
          "dev"
          "include"
          "lib"
          "static"
        ];
      };
      recursiveHash = builtins.throw "`recursiveHash` should never be required by redist-builder";
    };
    packageName = "cudnn";
    releaseInfo = {
      license = "cudnn";
      licensePath = null;
      name = "NVIDIA CUDA Deep Neural Network library";
      version = "8.6.0.166";
    };
  };

  debBuilderArgs = {
    manifestMajorMinorVersion = "35.6";
    sourceName = "cudnn";
    postDebUnpack =
      # Standard unpacking
      ''
        for dir in include lib; do
          mv "$sourceRoot/usr/$dir/aarch64-linux-gnu" "$sourceRoot/$dir"
        done
        rm -rf "$sourceRoot/usr"
      ''
      # Create symlinks for each header file in `include` without the `_v8` suffix before the file extension.
      + ''
        pushd "$sourceRoot/include"
        for file in *.h; do
          ln -s "$file" "$(basename "$file" "_v8.h").h"
        done
        popd
      '';
    srcIsNull = hostRedistArchIsUnsupported || cudaVersionIsUnsupported;
    overrideAttrsFn = prevAttrs: {
      brokenConditions = prevAttrs.brokenConditions // {
        "CUDA version mismatch" = cudaVersionIsUnsupported;
      };
      badPlatformsConditions = prevAttrs.badPlatformsConditions // {
        "CUDNN ${redistBuilderArgs.releaseInfo.version} is only available for Jetson devices" =
          hostRedistArchIsUnsupported;
      };
      buildInputs = prevAttrs.buildInputs or [ ] ++ [
        libcublas
        zlib
      ];
      # Tell patchelf about runtime dependencies. *_infer* libraries only exist in CuDNN 8.
      postFixup =
        prevAttrs.postFixup or ""
        + ''
          ${getExe patchelf} $lib/lib/libcudnn.so --add-needed libcudnn_cnn_infer.so
          ${getExe patchelf} $lib/lib/libcudnn_ops_infer.so --add-needed libcublas.so --add-needed libcublasLt.so
        '';
      meta = prevAttrs.meta // {
        platforms = prevAttrs.meta.platforms or [ ] ++ [ "aarch64-linux" ];
      };
    };
  };
in
callPackage ../deb-builder (redistBuilderArgs // debBuilderArgs)
