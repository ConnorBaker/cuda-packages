{
  autoPatchelfHook,
  buildPythonPackage,
  cudaPackages,
  lib,
  onnx,
  onnx-tensorrt, # from pkgs
  pycuda,
  stdenv,
  tensorrt,
}:
buildPythonPackage {
  __structuredAttrs = true;

  inherit (onnx-tensorrt) meta pname version;

  src = onnx-tensorrt.dist;

  format = "wheel";

  nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ]; # included to fail on missing dependencies

  unpackPhase = ''
    cp -r "$src" dist
    chmod +w dist
  '';

  doCheck = false; # Tests require a GPU

  dependencies = [
    (lib.getLib cudaPackages.cuda_cudart)
    onnx
    tensorrt
    pycuda
  ];

  # TODO: pycuda tries to load libcuda.so.1 immediately.
  # pythonImportsCheck = [ "onnx_tensorrt.backend" ];

  # TODO(@connorbaker): This derivation should contain Python tests for onnx-tensorrt.
}
