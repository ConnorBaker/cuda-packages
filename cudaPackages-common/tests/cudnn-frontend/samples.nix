{
  cudnn-frontend,
  flags,
  lib,
  writeShellApplication,
}:
let
  inherit (lib.meta) getExe';
in
writeShellApplication {
  derivationArgs = {
    __structuredAttrs = true;
    strictDeps = true;
  };
  name = "${flags.cudaNamePrefix}-tests-cudnn-frontend-samples";
  runtimeInputs = [ cudnn-frontend.samples ];
  text = ''
    args=( --rng-seed=0 )

    if (( $# != 0 ))
    then
      args=( "$@" )
    else
      echo "Running with default arguments: ''${args[*]}" >&2
    fi

    "${getExe' cudnn-frontend.samples "samples"}" "''${args[@]}"
  '';
}
