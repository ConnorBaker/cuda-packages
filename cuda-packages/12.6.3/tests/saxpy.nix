{
  backendStdenv,
  lib,
  saxpy,
  writeShellApplication,
}:
let
  inherit (lib.meta) getExe;
in
writeShellApplication {
  derivationArgs = {
    __structuredAttrs = true;
    strictDeps = true;
  };
  name = "${backendStdenv.cudaNamePrefix}-tests-saxpy";
  runtimeInputs = [ saxpy ];
  text = ''
    "${getExe saxpy}" "$@"
  '';
}
