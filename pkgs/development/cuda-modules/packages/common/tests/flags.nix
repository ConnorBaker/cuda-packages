{
  cudaConfig,
  cudaLib,
  lib,
  runCommand,
  stdenv,
}:
let
  inherit (builtins) deepSeq toJSON tryEval;
  inherit (cudaConfig.data) cudaCapabilityToInfo;
  inherit (cudaLib.utils) formatCapabilities;
  inherit (lib.asserts) assertMsg;
  inherit (stdenv) hostPlatform;
in
# When changing names or formats: pause, validate, and update the assert
assert assertMsg (
  cudaCapabilityToInfo ? "7.5" && cudaCapabilityToInfo ? "8.6"
) "The following test requires both 7.5 and 8.6 be known CUDA capabilities";
assert
  let
    expected = {
      cudaCapabilities = [
        "7.5"
        "8.6"
      ];
      cudaForwardCompat = true;

      archNames = [
        "Turing"
        "Ampere"
      ];
      realArchs = [
        "sm_75"
        "sm_86"
      ];
      virtualArchs = [
        "compute_75"
        "compute_86"
      ];
      archs = [
        "sm_75"
        "sm_86"
        "compute_86"
      ];

      gencode = [
        "-gencode=arch=compute_75,code=sm_75"
        "-gencode=arch=compute_86,code=sm_86"
        "-gencode=arch=compute_86,code=compute_86"
      ];
      gencodeString = "-gencode=arch=compute_75,code=sm_75 -gencode=arch=compute_86,code=sm_86 -gencode=arch=compute_86,code=compute_86";

      cmakeCudaArchitecturesString = "75;86";
    };
    actual = formatCapabilities {
      inherit cudaCapabilityToInfo;
      cudaCapabilities = [
        "7.5"
        "8.6"
      ];
    };
    actualWrapped = (tryEval (deepSeq actual actual)).value;
  in
  assertMsg (expected == actualWrapped) ''
    Expected: ${toJSON expected}
    Actual: ${toJSON actualWrapped}
  '';
# Check mixed Jetson and non-Jetson devices
assert assertMsg (
  cudaCapabilityToInfo ? "7.2" && cudaCapabilityToInfo ? "7.5"
) "The following test requires both 7.2 and 7.5 be known CUDA capabilities";
assert
  let
    expected = false;
    actual = formatCapabilities {
      inherit cudaCapabilityToInfo;
      cudaCapabilities = [
        "7.2"
        "7.5"
      ];
    };
    actualWrapped = (tryEval (deepSeq actual actual)).value;
  in
  assertMsg (expected == actualWrapped) ''
    Jetson devices capabilities cannot be mixed with non-jetson devices.
    Capability 7.5 is non-Jetson and should not be allowed with Jetson 7.2.
    Expected: ${toJSON expected}
    Actual: ${toJSON actualWrapped}
  '';
# Check Jetson-only
assert assertMsg (
  cudaCapabilityToInfo ? "7.2" && cudaCapabilityToInfo ? "8.7"
) "The following test requires both 7.2 and 8.7 be known CUDA capabilities";
assert
  let
    expected = {
      cudaCapabilities = [
        "7.2"
        "8.7"
      ];
      cudaForwardCompat = true;

      archNames = [
        "Volta"
        "Ampere"
      ];
      realArchs = [
        "sm_72"
        "sm_87"
      ];
      virtualArchs = [
        "compute_72"
        "compute_87"
      ];
      archs = [
        "sm_72"
        "sm_87"
        "compute_87"
      ];

      gencode = [
        "-gencode=arch=compute_72,code=sm_72"
        "-gencode=arch=compute_87,code=sm_87"
        "-gencode=arch=compute_87,code=compute_87"
      ];
      gencodeString = "-gencode=arch=compute_72,code=sm_72 -gencode=arch=compute_87,code=sm_87 -gencode=arch=compute_87,code=compute_87";

      cmakeCudaArchitecturesString = "72;87";
    };
    actual = formatCapabilities {
      inherit cudaCapabilityToInfo;
      cudaCapabilities = [
        "7.2"
        "8.7"
      ];
    };
    actualWrapped = (tryEval (deepSeq actual actual)).value;
  in
  assertMsg
    # We can't do this test unless we're targeting aarch64
    (hostPlatform.isAarch64 -> (expected == actualWrapped))
    ''
      Jetson devices can only be built with other Jetson devices.
      Both 7.2 and 8.7 are Jetson devices.
      Expected: ${toJSON expected}
      Actual: ${toJSON actualWrapped}
    '';
# Check mixed Accelerated and non-Accelerated devices
assert assertMsg (
  cudaCapabilityToInfo ? "9.0" && cudaCapabilityToInfo ? "9.0a"
) "The following test requires both 9.0 and 9.0a be known CUDA capabilities";
assert
  let
    expected = false;
    actual = formatCapabilities {
      inherit cudaCapabilityToInfo;
      cudaCapabilities = [
        "9.0"
        "9.0a"
      ];
    };
    actualWrapped = (tryEval (deepSeq actual actual)).value;
  in
  assertMsg (expected == actualWrapped) ''
    Accelerated device capabilities cannot be mixed with baseline devices.
    Capability 9.0 is not accelerated and should not be allowed with 9.0a.
    Expected: ${toJSON expected}
    Actual: ${toJSON actualWrapped}
  '';
runCommand "tests-flags"
  {
    __structuredAttrs = true;
    strictDeps = true;
  }
  ''
    touch "$out"
  ''
