# NOTE: This derivation is meant only for Jetsons.
# Links were retrieved from https://repo.download.nvidia.com/jetson.
{
  backendStdenv,
  callPackage,
  config,
  cuda-lib,
  cudaMajorMinorVersion,
  dpkg,
  fetchurl,
  srcOnly,
}:
let
  hostRedistArch = cuda-lib.utils.getRedistArch (
    config.data.jetsonTargets != [ ]
  ) backendStdenv.hostPlatform.system;
  hostRedistArchIsUnsupported = hostRedistArch != "linux-aarch64";
  cudaVersionIsUnsupported = cudaMajorMinorVersion != "11.8";

  # Dynamic libraries
  libcudnn8 = fetchurl {
    url = "https://repo.download.nvidia.com/jetson/common/pool/main/c/cudnn/libcudnn8_8.6.0.166-1+cuda11.4_arm64.deb";
    hash = "sha256-SmeblnbU0b/S16NXLu/JFnBiGa0Abjio/SN3Bn/WNe4=";
  };

  # Static libraries and headers
  libcudnn8-dev = fetchurl {
    url = "https://repo.download.nvidia.com/jetson/common/pool/main/c/cudnn/libcudnn8-dev_8.6.0.166-1+cuda11.4_arm64.deb";
    hash = "sha256-8jYyyxW6HbIJgRCGtcMSB9LaSUeEAkIrnZqqn+ncBRI=";
  };

  # Unpack and join the two debian archives
  unpacked = srcOnly {
    strictDeps = true;

    pname = "libcudnn8";
    version = "8.6.0.166-1+cuda11.4";
    name = "libcudnn8_8.6.0.166-1+cuda11.4_arm64-unpacked";

    srcs = [
      libcudnn8
      libcudnn8-dev
    ];

    nativeBuildInputs = [ dpkg ];

    # Set sourceRoot when we use a custom unpackPhase
    sourceRoot = "source";

    unpackPhase = ''
      runHook preUnpack
      dpkg-deb -x ${libcudnn8} "$sourceRoot"
      dpkg-deb -x ${libcudnn8-dev} "$sourceRoot"
      for dir in include lib; do
        mv "$sourceRoot/usr/$dir/aarch64-linux-gnu" "$sourceRoot/$dir"
      done
      rm -rf "$sourceRoot/usr"
      runHook postUnpack
    '';
  };

  unfixed-cudnn = callPackage ../redist-builder {
    # The redistributable builder expects src to be null when building on an unsupported platform or unavailable.
    src = if hostRedistArchIsUnsupported || cudaVersionIsUnsupported then null else unpacked;
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
in
unfixed-cudnn.overrideAttrs (prevAttrs: {
  brokenConditions = prevAttrs.brokenConditions // {
    "CUDA version mismatch" = cudaVersionIsUnsupported;
  };
  badPlatformsConditions = prevAttrs.badPlatformsConditions // {
    "CUDNN 8.6.0.166 is only available for Jetson devices" = hostRedistArchIsUnsupported;
  };
  meta = prevAttrs.meta // {
    platforms = prevAttrs.meta.platforms or [ ] ++ [ "aarch64-linux" ];
  };
})
