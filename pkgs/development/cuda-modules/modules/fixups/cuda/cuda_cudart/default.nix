{
  addDriverRunpath,
  arrayUtilities,
  autoFixElfFiles,
  cuda_cccl,
  cuda_compat,
  cuda_nvcc,
  cudaPackagesConfig,
  lib,
  patchelf,
}:
prevAttrs: {
  propagatedBuildOutputs = prevAttrs.propagatedBuildOutputs or [ ] ++ [
    "static" # required by CMake
    "stubs" # always propagate, even when cuda_compat is used, to avoid symbol linking errors
  ];

  # When cuda_compat is available, propagate it.
  # NOTE: `cuda_compat` can be disabled by setting the package to `null`. This is useful in cases where
  # the host OS has a recent enough CUDA driver that the compatibility library isn't needed.
  propagatedBuildInputs =
    prevAttrs.propagatedBuildInputs or [ ]
    # Add the dependency on NVCC's include directory.
    # - crt/host_config.h
    # TODO(@connorbaker): Check that the dependency offset for this is correct.
    ++ [ (lib.getOutput "include" cuda_nvcc) ]
    # Add the dependency on CCCL's include directory.
    # - nv/target
    # TODO(@connorbaker): Check that the dependency offset for this is correct.
    ++ [ (lib.getOutput "include" cuda_cccl) ]
    ++ lib.optionals (cudaPackagesConfig.hasJetsonCudaCapability && cuda_compat != null) [
      cuda_compat
    ];

  postPatch =
    prevAttrs.postPatch or ""
    # Patch the `cudart` package config files so they reference lib
    + ''
      local path=""
      while IFS= read -r -d $'\0' path; do
        nixLog "patching $path"
        sed -i \
          -e "s|^cudaroot\s*=.*\$||" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cudart-*.pc' -print0)
      unset -v path
    ''
    # Patch the `cuda` package config files so they reference stubs
    # TODO: Will this always pull in the stubs output and cause its setup hook to be executed?
    + ''
      local path=""
      while IFS= read -r -d $'\0' path; do
        nixLog "patching $path"
        sed -i \
          -e "s|^cudaroot\s*=.*\$||" \
          -e "s|^libdir\s*=.*/lib\$|libdir=''${!outputStubs:?}/lib/stubs|" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cuda-*.pc' -print0)
      unset -v path
    '';

  postInstall =
    prevAttrs.postInstall or ""
    # Namelink may not be enough, add a soname.
    # Cf. https://gitlab.kitware.com/cmake/cmake/-/issues/25536
    # NOTE: Relative symlinks is fine since this is all within the same output.
    + ''
      pushd "''${!outputStubs:?}/lib/stubs" >/dev/null
      if [[ -f libcuda.so && ! -f libcuda.so.1 ]]; then
        nixLog "creating versioned symlink for libcuda.so stub"
        ln -srv libcuda.so libcuda.so.1
      fi
      nixLog "creating symlinks for stubs in lib directory"
      ln -srvt "''${!outputStubs:?}/lib/" *.so *.so.*
      popd >/dev/null
    '';

  # Use postFixup because fixupPhase overwrites the dependency files in /nix-support.
  postFixup =
    let
      # Taken from:
      # https://github.com/NixOS/nixpkgs/blob/6527f230b4ac4cd7c39a4ab570500d8e2564e5ff/pkgs/stdenv/generic/make-derivation.nix#L421-L426
      getHostTarget = drv: lib.getDev drv.__spliced.hostTarget or drv;
    in
    prevAttrs.postFixup or ""
    # Install the setup hook
    # TODO(@connorbaker): Check that the dependency offset for this is correct.
    + ''
      mkdir -p "''${!outputStubs:?}/nix-support"

      if [[ -f "''${!outputStubs:?}/nix-support/setup-hook" ]]; then
        nixErrorLog "''${!outputStubs:?}/nix-support/setup-hook already exists, unsure if this is correct!"
        exit 1
      fi

      nixLog "installing cudaCudartRunpathFixupHook.bash to ''${!outputStubs:?}/nix-support/setup-hook"
      substitute \
        ${./cudaCudartRunpathFixupHook.bash} \
        "''${!outputStubs:?}/nix-support/setup-hook" \
        --subst-var-by cudaForceRpath "${if cudaPackagesConfig.cudaForceRpath then "1" else "0"}" \
        --subst-var-by cudartStubLibDir "''${!outputStubs:?}/lib" \
        --subst-var-by driverLibDir "${addDriverRunpath.driverLink}/lib"

      nixLog "installing cudaCudartRunpathFixupHook.bash propagatedBuildInputs to ''${!outputStubs:?}/nix-support/propagated-build-inputs"
      printWords \
        "${getHostTarget arrayUtilities.arrayReplace}" \
        "${getHostTarget arrayUtilities.getRunpathEntries}" \
        "${getHostTarget arrayUtilities.occursInArray}" \
        "${getHostTarget autoFixElfFiles}" \
        "${getHostTarget patchelf}" \
        >>"''${!outputStubs:?}/nix-support/propagated-build-inputs"
    '';

  passthru = prevAttrs.passthru or { } // {
    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      # NOTE: A number of packages expect cuda_cudart to be in a single directory.
      outputs = [
        "out"
        "dev"
        "include"
        "lib"
        "static"
        "stubs"
      ];
    };
  };
}
