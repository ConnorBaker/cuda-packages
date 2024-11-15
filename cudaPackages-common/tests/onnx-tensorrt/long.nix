{
  flags,
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
  name = "${flags.cudaNamePrefix}-tests-onnx-tensorrt-short";
  runtimeInputs = [
    cuda_cudart
    (python3.withPackages (ps: [
      onnx-tensorrt
      ps.pytest
      ps.six
    ]))
  ];
  text = ''
    args=( --verbose )

    if (( $# != 0 ))
    then
      args=( "$@" )
    else
      echo "Running with default arguments: ''${args[*]}" >&2
    fi

    python3 "${onnx-tensorrt.test_script}/onnx_backend_test.py" "''${args[@]}"
  '';
}
