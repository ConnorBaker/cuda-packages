{
  buildPythonPackage,
  cuda-python,
  cudaPackages,
  cutlass,
  networkx,
  numpy,
  pydot,
  pytestCheckHook,
  python,
  runCommand,
  scipy,
  treelib,
  writeTextFile,
}:
let
  inherit (cudaPackages)
    cuda_cudart
    cuda_nvcc
    ;
in
buildPythonPackage {
  __structuredAttrs = true;

  inherit (cudaPackages.cutlass)
    meta
    pname
    version
    ;

  src = cudaPackages.cutlass.dist;

  format = "wheel";

  unpackPhase = ''
    cp -rv "$src" dist
    chmod +w dist
  '';

  dependencies = [
    cuda-python
    networkx
    numpy
    pydot
    scipy
    treelib
  ];

  # When building intermediate Python packages, we use `dependencies`, which maps to propagatedBuildInputs.
  # However, when we run python packages, we do so on the build/host platform.
  propagatedNativeBuildInputs = [
    # no cuda_cudart
    cuda_nvcc # cutlass in buildInputs -> cuda_nvcc in be nativeBuildInputs
  ];
  propagatedBuildInputs = [
    cuda_cudart # cutlass in buildInputs -> cuda_cudart in buildInputs
    cuda_nvcc # cutlass in nativeBuildInputs -> cuda_nvcc in nativeBuildInputs
  ];
  depsTargetTargetPropagated = [
    cuda_cudart # cutlass in nativeBuildInputs -> cuda_cudart in buildInputs
    # no cuda_nvcc
  ];

  doCheck = false;

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "cutlass" ];

  passthru.tests = {
    cutlass-installation =
      runCommand "cutlass-installation-test"
        {
          __structuredAttrs = true;
          strictDeps = true;
          nativeBuildInputs = [
            cutlass
            python
          ];
          requiredSystemFeatures = [ "cuda" ];
        }
        ''
          set -euo pipefail
          python3 "${cudaPackages.cutlass.src}/test/python/cutlass/installation.py"
          touch "$out"
        '';
    numpy =
      let
        script = writeTextFile {
          name = "cutlass-numpy-test.py";
          executable = true;
          text = ''
            import cutlass
            import numpy as np

            plan = cutlass.op.Gemm(element=np.float16, layout=cutlass.LayoutType.RowMajor)
            A, B, C, D = [np.ones((128, 128), dtype=np.float16) for i in range(4)]
            plan.run(A, B, C, D)
          '';
        };
      in
      runCommand "cutlass-python-numpy-test"
        {
          __structuredAttrs = true;
          strictDeps = true;
          nativeBuildInputs = [
            cutlass
            numpy
            python
          ];
          requiredSystemFeatures = [ "cuda" ];
        }
        ''
          set -euo pipefail
          python3 "${script}" || {
            nixErrorLog "cutlass numpy test failed; outputting all local files to stdout"
            for text_file in *.txt; do
              echo "Contents of $text_file:"
              cat "$text_file"
            done
            exit 1
          }
          touch "$out"
        '';
    pycute =
      runCommand "cutlass-pycute-test"
        {
          __structuredAttrs = true;
          strictDeps = true;
          nativeBuildInputs = [
            cutlass
            python
          ];
          requiredSystemFeatures = [ "cuda" ];
        }
        ''
          set -euo pipefail
          python3 "${cudaPackages.cutlass.src}/test/python/pycute/run_all_tests.py"
          touch "$out"
        '';
  };

  # TODO: CUTLASS looks like it caches kernel compilation in a database store alongside it.
  # That won't work for us since the store path is immutable.
  # https://github.com/NVIDIA/cutlass/blob/e94e888df3551224738bfa505787b515eae8352f/python/cutlass/backend/compiler.py#L132
}
