{
  addDriverRunpath,
  autoFixElfFiles,
  arrayUtilities,
  cudaPackagesConfig,
  lib,
  patchelf,
}:
# NOTE: Because we keep the output entirely in `compat`, autoPatchelfHook won't find our try to link against
# `compat/libcuda.so` and programs will instead link against the stubs provided by cuda_cudart.
# This saves us from missing symbol errors as we can't link against the driver-provided `libcuda.so`, which
# `cuda_compat/libcuda.so` requires.
# Thanks to the setup hook for cuda_cudart, RPATH entries to the stub file are removed and the driverLink path
# added at the end of the RPATH.
# When cuda_compat is used, our setup hook will add the path to the compat directory to the front of the RPATH,
# ensuring the compat library is found before the driver-provided library.
prevAttrs: {
  allowFHSReferences = true;

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps or [ ]
    ++ lib.optionals cudaPackagesConfig.hasJetsonCudaCapability [
      "libnvrm_gpu.so"
      "libnvrm_mem.so"
      "libnvdla_runtime.so"
    ];

  # Use postFixup because fixupPhase overwrites the dependency files in /nix-support.
  postFixup =
    let
      # Taken from:
      # https://github.com/NixOS/nixpkgs/blob/6527f230b4ac4cd7c39a4ab570500d8e2564e5ff/pkgs/stdenv/generic/make-derivation.nix#L421-L426
      getHostHost = drv: lib.getDev drv.__spliced.hostHost or drv;
      getHostTarget = drv: lib.getDev drv.__spliced.hostTarget or drv;
    in
    prevAttrs.postFixup or ""
    # Install the setup hook in `out`, since the other outputs are symlinks to `out` (ensuring `out`'s setup hook is
    # always sourced).
    + ''
      mkdir -p "''${out:?}/nix-support"

      if [[ -f "''${out:?}/nix-support/setup-hook" ]]; then
        nixErrorLog "''${out:?}/nix-support/setup-hook already exists, unsure if this is correct!"
        exit 1
      fi

      nixLog "installing cudaCompatRunpathFixupHook.bash to ''${out:?}/nix-support/setup-hook"
      substitute \
        ${./cudaCompatRunpathFixupHook.bash} \
        "''${out:?}/nix-support/setup-hook" \
        --subst-var-by cudaForceRpath "${if cudaPackagesConfig.cudaForceRpath then "1" else "0"}" \
        --subst-var-by cudaCompatOutDir "''${out:?}/compat" \
        --subst-var-by cudaCompatLibDir "''${!outputLib:?}/lib" \
        --subst-var-by driverLibDir "${addDriverRunpath.driverLink}/lib"

      nixLog "installing cudaCompatRunpathFixupHook.bash depsHostHostPropagated to ''${out:?}/nix-support/propagated-host-host-deps"
      printWords \
        "${getHostHost arrayUtilities.arrayDifference}" \
        "${getHostHost arrayUtilities.getRunpathEntries}" \
        "${getHostHost arrayUtilities.occursInArray}" \
        >>"''${out:?}/nix-support/propagated-host-host-deps"

      nixLog "installing cudaCompatRunpathFixupHook.bash propagatedBuildInputs to ''${out:?}/nix-support/propagated-build-inputs"
      printWords \
        "${getHostTarget autoFixElfFiles}" \
        "${getHostTarget patchelf}" \
        >>"''${out:?}/nix-support/propagated-build-inputs"
    '';

  passthru = prevAttrs.passthru or { } // {
    # `cuda_compat` only works on aarch64-linux, and only when building for Jetson devices.
    badPlatformsConditions = prevAttrs.passthru.badPlatformsConditions or { } // {
      "Trying to use cuda_compat on aarch64-linux targeting non-Jetson devices" =
        !cudaPackagesConfig.hasJetsonCudaCapability;
    };

    # NOTE: Using multiple outputs with symlinks causes build cycles.
    # To avoid that (and troubleshooting why), we just use a single output.
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [ "out" ];
    };
  };
}
