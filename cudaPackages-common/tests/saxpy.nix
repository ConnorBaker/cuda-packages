{
  flags,
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
  name = "${flags.cudaNamePrefix}-tests-saxpy";
  runtimeInputs = [ saxpy ];
  text = ''
    "${getExe saxpy}" "$@"
  '';
}
