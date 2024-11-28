{
  backendStdenv,
  cuda_cudart,
  onnx-tensorrt,
  python3,
  writeShellApplication,
}:
writeShellApplication {
  derivationArgs = {
    __structuredAttrs = true;
    strictDeps = true;
  };
  name = "${backendStdenv.cudaNamePrefix}-tests-onnx-tensorrt-short";
  runtimeInputs = [
    cuda_cudart
    (python3.withPackages (ps: [
      onnx-tensorrt
      ps.pytest
      ps.six
    ]))
  ];
  text = ''
    args=(
      python3
      "${onnx-tensorrt.test_script}/onnx_backend_test.py"
    )

    if (( $# != 0 ))
    then
      args+=( "$@" )
    else
      args+=(
        --verbose
        OnnxBackendRealModelTest
      )
      echo "Running with default arguments: ''${args[*]}" >&2
    fi

    "''${args[@]}"
  '';
}
