{
  autoPatchelfHook,
  lib,
  python3,
  tensorrt_10_4,
}:
let
  inherit (lib.attrsets) getLib;
  inherit (python3.pkgs) buildPythonPackage;
in
buildPythonPackage {
  strictDeps = true;

  pname = "tensorrt-python";
  inherit (tensorrt_10_4) version;
  format = "wheel";

  # TODO: Selection logic to choose the correct wheel based on Python version and platform.
  src = "${tensorrt_10_4.python}/python/tensorrt-10.4.0-cp312-none-linux_x86_64.whl";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ (getLib tensorrt_10_4) ];

  pythonImportsCheck = [ "tensorrt" ];

  meta = with lib; {
    maintainers = with maintainers; [ connorbaker ];
  };
}
