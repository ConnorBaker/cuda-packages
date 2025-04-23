{
  autoPatchelfHook,
  buildPythonPackage,
  google-re2,
  lib,
  nbval,
  numpy,
  onnx, # from pkgs
  parameterized,
  pillow,
  pytestCheckHook,
  stdenv,
}:
buildPythonPackage {
  __structuredAttrs = true;

  inherit (onnx)
    meta
    passthru
    pname
    version
    ;

  src = onnx.dist;

  format = "wheel";

  nativeBuildInputs =
    [ pytestCheckHook ]
    # included to fail on missing dependencies
    ++ lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];

  unpackPhase = ''
    cp -rv "$src" dist
    cp -rv "${onnx.src}"/onnx/test test
    chmod +w dist test
  '';

  buildInputs = [
    onnx # for libonnx.so
  ];

  dependencies = [ onnx.passthru.pyProtobuf ];

  doCheck = true;

  checkInputs = [
    google-re2
    nbval
    numpy
    parameterized
    pillow
  ];

  # Fixups for pytest
  preCheck = ''
    nixLog "setting HOME to a temporary directory for pytest"
    export HOME="$(mktemp --directory)"
    trap "rm -rf -- ''${HOME@Q}" EXIT
  '';

  pythonImportsCheck = [ "onnx" ];

  # TODO(@connorbaker): This derivation should contain Python tests for onnx.
}
