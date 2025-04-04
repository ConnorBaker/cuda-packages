{
  addDriverRunpath,
  arrayUtilities,
  cudaPackagesConfig,
  lib,
}:
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
    prevAttrs.postFixup or ""
    # Install the setup hook
    + ''
      mkdir -p "''${out:?}/nix-support"

      if [[ -f "''${out:?}/nix-support/setup-hook" ]]; then
        nixErrorLog "''${out:?}/nix-support/setup-hook already exists, unsure if this is correct!"
        exit 1
      fi

      nixErrorLog "@connorbaker: this is incorrect, fix it"
      exit 1

      nixLog "installing cudaCudartRunpathFixupHook.bash to ''${out:?}/nix-support/setup-hook"
      substitute \
        ${./cudaCompatRunpathFixupHook.bash} \
        "''${out:?}/nix-support/setup-hook" \
        --subst-var-by cudaCompatOutDir "''${out:?}/compat" \
        --subst-var-by cudaCompatLibDir "''${!outputLib:?}/lib" \
        --subst-var-by driverLibDir "${addDriverRunpath.driverLink}/lib"

      nixLog "installing cudaCudartRunpathFixupHook.bash dependencies to ''${out:?}/nix-support/propagated-host-host-deps"
      printWords \
        "${arrayUtilities.occursInArray}" \
        "${arrayUtilities.getRunpathEntries}" \
        >>"''${out:?}/nix-support/propagated-host-host-deps"
    '';

  passthru = prevAttrs.passthru or { } // {
    # `cuda_compat` only works on aarch64-linux, and only when building for Jetson devices.
    badPlatformsConditions = prevAttrs.passthru.badPlatformsConditions or { } // {
      "Trying to use cuda_compat on aarch64-linux targeting non-Jetson devices" =
        !cudaPackagesConfig.hasJetsonCudaCapability;
    };

    # TODO(@connorbaker): Keep `compat` as a directory; symlink .so.* files to `lib` and binaries to `bin`.
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      outputs = [
        "out"
        "bin"
        "dev"
        "lib"
      ];
    };
  };
}
