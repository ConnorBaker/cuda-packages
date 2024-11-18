{
  backendStdenv,
  cudnn-frontend,
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
  name = "${backendStdenv.cudaNamePrefix}-tests-cudnn-frontend-legacy-samples";
  runtimeInputs = [ cudnn-frontend.legacy_samples ];
  text = ''
    args=(
      --rng-seed=0
      exclude:"Scale Bias Conv BNGenstats with CPU Reference"
    )

    if (( $# != 0 ))
    then
      args=( "$@" )
    else
      echo "Running with default arguments: ''${args[*]}" >&2
    fi

    "${getExe' cudnn-frontend.legacy_samples "legacy_samples"}" "''${args[@]}"
  '';
}
