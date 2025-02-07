{
  cuda_cudart,
  python3,
  writeShellApplication,
}:
writeShellApplication {
  derivationArgs = {
    __structuredAttrs = true;
    strictDeps = true;
  };
  name = "tests-onnx-tensorrt-long";
  runtimeInputs = [
    cuda_cudart
    (python3.withPackages (ps: [
      ps.onnx-tensorrt
      ps.pytest
      ps.six
    ]))
  ];
  text = ''
    args=(
      python3
      "${python3.pkgs.onnx-tensorrt.test_script}/onnx_backend_test.py"
    )

    if (( $# != 0 ))
    then
      args+=( "$@" )
    else
      args+=( --verbose )
      echo "Running with default arguments: ''${args[*]}" >&2
    fi

    chmod -R +w "$HOME/.onnx"
    "''${args[@]}"
  '';
}
