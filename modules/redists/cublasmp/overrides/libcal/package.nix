{
  cuda_cudart,
  lib,
  ucc,
}:
let
  inherit (lib.attrsets) getOutput;
  inherit (lib.lists) elem;
  inherit (lib.strings) optionalString;
in
finalAttrs: prevAttrs: {
  allowFHSReferences = true;
  buildInputs = prevAttrs.buildInputs ++ [
    (getOutput "stubs" cuda_cudart)
    ucc
  ];
  env.NIX_DEBUG = "1";

  # TODO: UCC looks for share/ucc.conf in the same output as the shared object files, so we need to make a hook to set
  # the environment variable UCC_CONF_PATH to the correct location.
  postInstall = optionalString (elem "out" finalAttrs.outputs) ''
    mkdir -p "$out/nix-support"
    cat "${./set-ucc-config-file-hook.sh}" >> "$out/nix-support/setup-hook"
    substituteInPlace "$out/nix-support/setup-hook" \
      --replace-fail "@out@" "${builtins.placeholder "out"}"
  '';
}
