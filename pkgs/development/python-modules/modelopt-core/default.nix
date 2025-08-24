{
  buildPythonPackage,
  cudaPackages,
  fetchurl,
  lib,
  python,
  pythonOlder,
  pythonAtLeast,
  stdenv,
}:
let
  # ABI -> Python -> Platform -> Version -> SHA256
  # Taken from https://pypi.nvidia.com/nvidia-modelopt-core/
  releases = {
    py3 = {
      cp39 = {
        manylinux_2_28_aarch64 = {
          "0.27.1" = "3e06a96c7c2dc75239ca59d4f3fd8ee922b9b6a290d485e8e61436bc17f9ae40";
        };
        manylinux_2_28_x86_64 = {
          "0.27.1" = "301ad28ce2adf03733931c0014ed80102d707546f33f850ebd0e95e29e7d6b61";
        };
      };
      cp310 = {
        manylinux_2_28_aarch64 = {
          "0.27.1" = "4184d2838696f8563c3cdff66f94b71ab2a6d2b8a3b181f04fe12dc03944fb98";
        };
        manylinux_2_28_x86_64 = {
          "0.27.1" = "918ad3b8580036fda803bfbb1bc4483cfe62a49d0572e027570430771fd31fb1";
        };
      };
      cp311 = {
        manylinux_2_28_aarch64 = {
          "0.27.1" = "f13f698ab28459e00974776bb050c336b17d33dd03acc52874ffa7c450cb566f";
        };
        manylinux_2_28_x86_64 = {
          "0.27.1" = "47283de5c14d316bf52c709996c7d10507ff6fd72b76a6509083bc2610a92a93";
        };
      };
      cp312 = {
        manylinux_2_28_aarch64 = {
          "0.27.1" = "9ba2c87d1b88e5e14795c1c5ce157939068c939f4186bd8158c793e7c03ada85";
        };
        manylinux_2_28_x86_64 = {
          "0.27.1" = "b63e606c55d95137ffd7f2296d463e454a1496ddff10fe29c5c289b066d8d596";
        };
      };
    };
  };

  finalAttrs =
    let
      inherit (stdenv.hostPlatform) parsed;

      pythonVersionNoDots = lib.replaceStrings [ "." ] [ "" ] (lib.versions.majorMinor python.version);

      platform = "manylinux_2_28_${parsed.cpu.name}";

      # NOTE: Yes, the ABI and python are the same.
      # NVIDIA's URLs are inconsistent.
      wheelName = "nvidia_${finalAttrs.pname}-${finalAttrs.version}-cp${pythonVersionNoDots}-cp${pythonVersionNoDots}-${platform}.whl";
      wheelSha256 = releases.py3."cp${pythonVersionNoDots}".${platform}.${finalAttrs.version} or "";
    in
    {
      __structuredAttrs = true;

      pname = "modelopt_core";
      version = "0.27.1";

      disabled = pythonOlder "3.9" || pythonAtLeast "3.13" || wheelSha256 == "";

      format = "wheel";

      src = fetchurl {
        name = wheelName;
        sha256 = wheelSha256;
        url = "https://pypi.nvidia.com/nvidia-modelopt-core/${wheelName}#sha256=${wheelSha256}";
      };

      unpackPhase = ''
        mkdir -p dist
        cp -v "$src" "dist/${wheelName}"
        chmod +w dist
      '';

      pythonImportsCheck = [ "modelopt_core" ];

      # TODO: Need to finish meta attribute.
      meta = {
        broken = cudaPackages.backendStdenv.hasJetsonCudaCapability;
        platforms = [
          "aarch64-linux"
          "x86_64-linux"
        ];
      };
    };
in
buildPythonPackage finalAttrs
