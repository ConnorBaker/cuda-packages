{
  autoPatchelfHook,
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
  # Taken from https://pypi.nvidia.com/nvidia-nvcomp-cu12/
  releases = {
    py3 = {
      none = {
        manylinux_2_28_aarch64 = {
          "4.2.0.14" = "bd67b77f7d18daa60757a3400444bf8cc6056dc4d806e22b3a13561f26db692c";
        };
        manylinux_2_28_x86_64 = {
          "4.2.0.14" = "0d9bc07bf63aeae2e9877d34c8aab6781cf26efa8d2fec05af8b0ec58ca1fd41";
        };
      };
    };
  };

  finalAttrs =
    let
      inherit (stdenv.hostPlatform) parsed;

      pythonVersionNoDots = lib.replaceStrings [ "." ] [ "" ] (lib.versions.majorMinor python.version);

      platform = "manylinux_2_28_${parsed.cpu.name}";

      wheelName = "nvidia_${finalAttrs.pname}_cu12-${finalAttrs.version}-py3-none-${platform}.whl";
      wheelSha256 = releases.py3.none.${platform}.${finalAttrs.version};
    in
    {
      __structuredAttrs = true;

      inherit (cudaPackages.nvcomp) meta pname;

      # NOTE: The version is not constrained to that of cudaPackages.nvcomp, as NVIDIA ships a different binary for the library
      # in the wheel.
      version = "4.2.0.14";

      disabled =
        pythonOlder "3.9" || pythonAtLeast "3.13" || cudaPackages.cudaOlder "12.0" || wheelSha256 == "";

      format = "wheel";

      src = fetchurl {
        name = wheelName;
        sha256 = wheelSha256;
        url = "https://pypi.nvidia.com/nvidia-nvcomp-cu12/${wheelName}#sha256=${wheelSha256}";
      };
      # https://pypi.nvidia.com/nvidia-nvcomp-cu12/nvidia_nvcomp_cu12-4.2.0.11-py3-none-manylinux_2_28_x86_64.whl#sha256=e0f7fb7a21386b776a90ab163e76ae8c87ba89dcbcd85365dababf33bb78be03
      # https://pypi.nvidia.com/nvidia-nvcomp-cu12/nvidia_nvcomp_cu12-4.2.0.11-py3-none-manylinux_2_28_x86_64-linux.whl#sha256=e0f7fb7a21386b776a90ab163e76ae8c87ba89dcbcd85365dababf33bb78be03

      # included to fail on missing dependencies
      nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

      unpackPhase = ''
        mkdir -p dist
        cp -v "$src" "dist/${wheelName}"
        chmod +w dist
      '';

      postInstall =
        let
          keep = "nvcomp_impl.cpython-${pythonVersionNoDots}-${parsed.cpu.name}-${parsed.kernel.name}-${parsed.abi.name}.so";
        in
        ''
          nixLog "removing unused libraries"
          pushd "$out/${python.sitePackages}/nvidia/nvcomp" > /dev/null
          mv -v "${keep}" "${keep}.keep"
          rm -v nvcomp_impl.cpython-*.so
          mv -v "${keep}.keep" "${keep}"
          popd > /dev/null
        '';

      pythonImportsCheck = [ "nvidia.nvcomp" ];

      # TODO: Need a meta attribute.

      # TODO: Unsupported on Jetson devices.
    };
in
buildPythonPackage finalAttrs
