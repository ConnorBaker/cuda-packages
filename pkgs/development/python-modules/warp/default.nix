{
  autoAddDriverRunpath,
  buildPythonPackage,
  cudaPackages,
  fetchFromGitHub,
  lib,
  numpy,
  pkgsBuildHost,
  python,
  runCommand,
  setuptools,
  warp,
  writableTmpDirAsHomeHook,
}:
let
  inherit (cudaPackages)
    cuda_cccl
    cuda_cudart
    cuda_nvcc
    cuda_nvrtc
    flags
    libmathdx
    libnvjitlink
    ;
  inherit (lib) maintainers teams;
  inherit (lib.attrsets) getBin getOutput;
  inherit (lib.strings) concatMapStringsSep;

  finalAttrs = {
    __structuredAttrs = true;

    pname = "warp";

    version = "1.7.1-unstable-2025-05-02";

    src = fetchFromGitHub {
      owner = "NVIDIA";
      repo = "warp";
      rev = "a97968d3a87f15b9d891822c16c5af0e5a700492";
      hash = "sha256-9zTlabg48mT3eyJJf2uqeg1ydE/cU8epoOsZDvRCR0A=";
    };

    pyproject = true;

    build-system = [ setuptools ];

    # NOTE: While normally we wouldn't include autoAddDriverRunpath for packages built from source, since Warp
    # will be loading GPU drivers at runtime, we need to inject the path to our video drivers.
    nativeBuildInputs = [
      autoAddDriverRunpath
      cuda_nvcc
    ];

    prePatch =
      # Patch build_dll.py to use our gencode flags rather than NVIDIA's very broad defaults.
      ''
        nixLog "patching $PWD/warp/build_dll.py to use our gencode flags"
        substituteInPlace "$PWD/warp/build_dll.py" \
          --replace-fail \
            '*gencode_opts,' \
            '${concatMapStringsSep ", " (gencodeString: ''"${gencodeString}"'') flags.gencode},' \
          --replace-fail \
            '*clang_arch_flags,' \
            '${concatMapStringsSep ", " (realArch: ''"--cuda-gpu-arch=${realArch}"'') flags.realArchs},'
      ''
      # Patch build_dll.py to use dynamic libraries rather than static ones.
      # NOTE: We do not patch the `nvptxcompiler_static` path because it is not available as a dynamic library.
      + ''
        nixLog "patching $PWD/warp/build_dll.py to use dynamic libraries"
        substituteInPlace "$PWD/warp/build_dll.py" \
          --replace-fail \
            '-lcudart_static' \
            '-lcudart' \
          --replace-fail \
            '-lnvrtc_static' \
            '-lnvrtc' \
          --replace-fail \
            '-lnvrtc-builtins_static' \
            '-lnvrtc-builtins' \
          --replace-fail \
            '-lnvJitLink_static' \
            '-lnvJitLink' \
          --replace-fail \
            '-lmathdx_static' \
            '-lmathdx'
      '';

    # Run the build script which creates components necessary to build the wheel.
    # NOTE: Building standalone allows us to avoid trying to fetch a pre-built binary or
    # bootstraping Clang/LLVM.
    # TODO: Allow re-use of existing LLVM/Clang binaries instead of building from source to support the CPU backend.
    # NOTE: The `cuda_path` argument is the directory which contains `bin/nvcc`.
    preBuild = ''
      nixLog "running $PWD/build_lib.py to create components necessary to build the wheel"
      "${python.pythonOnBuildForHost.interpreter}" "$PWD/build_lib.py" \
        --cuda_path "${getBin pkgsBuildHost.cudaPackages.cuda_nvcc}" \
        --libmathdx_path "${libmathdx}" \
        --quick \
        --no_standalone
    '';

    dependencies = [ numpy ];

    buildInputs = [
      (getOutput "include" cuda_cccl) # <cub/cub.cuh>
      (getOutput "static" cuda_nvcc) # dependency on nvptxcompiler_static; no dynamic version available
      cuda_cudart
      cuda_nvcc
      cuda_nvrtc
      libmathdx
      libnvjitlink
    ];

    # Requires a CUDA device to run GPU tests, which is what we care about.
    doCheck = false;

    pythonImportsCheck = [ "warp" ];

    # TODO: Unable to disable some of the tests that are failing.
    passthru.tests.unit =
      runCommand "warp-unit-tests"
        {
          __structuredAttrs = true;
          strictDeps = true;
          nativeBuildInputs = [
            python
            warp
            writableTmpDirAsHomeHook
          ];
          skippedTestClasses = [
            # CPU backend required

            "TestVolume"
            "TestVolumeWrite"

            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_name='float', codec='none')
            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_name='float', codec='zip')
            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_name='vec3f', codec='none')
            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_name='vec3f', codec='zip')
            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_name='index', codec='none')
            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_name='index', codec='zip')
            # test_volume_write_cpu (warp.tests.geometry.test_volume.TestVolume.test_volume_write_cpu) (volume_write='unsupported')

            # AttributeError: 'NoneType' object has no attribute 'compile_cpp'

            "TestVbd"
            "TestArray"
            # "TestAssertDebug" # NOTE: No test class of this name
            # "TestAssertRelease" # NOTE: No test class of this name
            "TestFastMath"
            "TestIter"
            "TestSnippets"

            # test_vbd_bending_cuda_0 (warp.tests.sim.test_vbd.TestVbd.test_vbd_bending_cuda_0)
            # test_vbd_bending_non_zero_rest_angle_bending_cuda_0 (warp.tests.sim.test_vbd.TestVbd.test_vbd_bending_non_zero_rest_angle_bending_cuda_0)
            # test_vbd_collision_cuda_0 (warp.tests.sim.test_vbd.TestVbd.test_vbd_collision_cuda_0)
            # test_direct_from_numpy_cpu (warp.tests.test_array.TestArray.test_direct_from_numpy_cpu)
            # test_basic_assert_false_condition (warp.tests.test_assert.TestAssertDebug.test_basic_assert_false_condition)
            # test_basic_assert_false_condition (warp.tests.test_assert.TestAssertRelease.test_basic_assert_false_condition)
            # test_fast_math_cpu (warp.tests.test_fast_math.TestFastMath.test_fast_math_cpu)
            # test_reversed_cuda_0 (warp.tests.test_iter.TestIter.test_reversed_cuda_0)
            # test_cpu_snippet_cpu (warp.tests.test_snippet.TestSnippets.test_cpu_snippet_cpu)

            # KeyError: 'test_pow_114c30ca_cuda_kernel_forward_smem_bytes'

            # test_fast_math_cuda_cuda_0 (warp.tests.test_fast_math.TestFastMath.test_fast_math_cuda_cuda_0)
            # test_fast_math_disabled_cuda_0 (warp.tests.test_fast_math.TestFastMath.test_fast_math_disabled_cuda_0)

            # PermissionError: [Errno 13] Permission denied: '/nix/store/n7s3hfn2arhwfdhfh6741q2kcib56s0i-python3.12-warp-1.7.1-unstable-2025-05-02/lib/python3.12/site-packages/warp/tests'

            "TestReload"

            # test_reload_cuda_0 (warp.tests.test_reload.TestReload.test_reload_cuda_0)
            # test_reload_references_cuda_0 (warp.tests.test_reload.TestReload.test_reload_references_cuda_0)

            # AssertionError: Regex didn't match: 'Assertion failed

            # test_basic_assert_false_condition_function (warp.tests.test_assert.TestAssertDebug.test_basic_assert_false_condition_function)
            # test_basic_assert_with_msg (warp.tests.test_assert.TestAssertDebug.test_basic_assert_with_msg)
            # test_compound_assert_false_condition (warp.tests.test_assert.TestAssertDebug.test_compound_assert_false_condition)
          ];
          requiredSystemFeatures = [ "cuda" ];
        }
        ''
          cp -rv "${warp.src}/warp/tests" .
          chmod -R u+w tests
          for skippedTestClass in "''${skippedTestClasses[@]}"; do
            nixLog "patching $PWD/tests/unittest_suites.py to skip test class $skippedTestClass"
            substituteInPlace "$PWD/tests/unittest_suites.py" \
              --replace-fail \
                "$skippedTestClass," \
                "# $skippedTestClass,"
          done
          python3 -m warp.tests -s default
        '';

    meta = {
      description = "A Python framework for high performance GPU simulation and graphics";
      homepage = "https://github.com/NVIDIA/warp";
      license = {
        fullName = "NVIDIA Software License Agreement";
        shortName = "NVIDIA SLA";
        url = "https://www.nvidia.com/en-us/agreements/enterprise-software/nvidia-software-license-agreement/";
        free = false;
      };
      platforms = [
        "aarch64-linux"
        "x86_64-linux"
      ];
      maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
    };
  };
in
buildPythonPackage finalAttrs
