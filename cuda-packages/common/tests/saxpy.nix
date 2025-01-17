{
  cudaStdenv,
  lib,
  saxpy,
  writeShellApplication,
}:
let
  inherit (cudaStdenv) cudaNamePrefix;
  inherit (lib.meta) getExe;
in
writeShellApplication {
  derivationArgs = {
    __structuredAttrs = true;
    strictDeps = true;
  };
  name = "${cudaNamePrefix}-tests-saxpy";
  runtimeInputs = [ saxpy ];
  text = ''
    "${getExe saxpy}" "$@"
  '';
}
