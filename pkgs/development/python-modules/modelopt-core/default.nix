{
  autoPatchelfHook,
  buildPythonPackage,
  fetchurl,
  lib,
  python,
  pythonOlder,
  pythonAtLeast,
  stdenv,
}:
let
  abi = "cp${lib.replaceStrings [ "." ] [ "" ] (lib.versions.majorMinor python.version)}";
  platform = "manylinux_2_28_x86_64";
  sha256 = "b63e606c55d95137ffd7f2296d463e454a1496ddff10fe29c5c289b066d8d596";

  finalAttrs = {
    __structuredAttrs = true;

    pname = "modelopt_core";
    version = "0.27.1";

    disabled = pythonOlder "3.9" || pythonAtLeast "3.13";

    format = "wheel";

    src = fetchurl {
      name = "nvidia_${finalAttrs.pname}-${finalAttrs.version}-${abi}-${abi}-${platform}.whl";
      inherit sha256;
      url = "https://pypi.nvidia.com/nvidia-modelopt-core/${finalAttrs.src.name}#sha256=${sha256}";
    };

    # included to fail on missing dependencies
    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

    unpackPhase = ''
      mkdir -p dist
      cp -v "$src" "dist/${finalAttrs.src.name}"
      chmod +w dist
    '';

    pythonImportsCheck = [ "modelopt_core" ];

    # TODO: Need a meta attribute.

    # TODO: Unsupported on Jetson devices.
    meta.platforms = [ "x86_64-linux" ];
  };
in
buildPythonPackage finalAttrs
