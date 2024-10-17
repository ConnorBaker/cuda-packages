{
  autoPatchelfHook,
  backendStdenv,
  cuda-lib,
  lib,
  python3,
  tensorrt,
}:
let
  inherit (cuda-lib.utils) dropDots majorMinorPatch;
  inherit (lib.attrsets) getLib;
  inherit (lib.versions) majorMinor;
  inherit (python3.pkgs) buildPythonPackage;
in
buildPythonPackage {
  strictDeps = true;
  stdenv = backendStdenv;

  pname = "tensorrt-python";
  inherit (tensorrt) version;
  format = "wheel";

  # TODO: Selection logic to choose the correct wheel based on Python version and platform.
  src = "${tensorrt.python}/python/tensorrt-${majorMinorPatch tensorrt.version}-cp${dropDots (majorMinor python3.version)}-none-linux_x86_64.whl";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ (getLib tensorrt) ];

  pythonImportsCheck = [ "tensorrt" ];

  meta = with lib; {
    maintainers = with maintainers; [ connorbaker ];
  };
}
