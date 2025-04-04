{
  addDriverRunpath,
  arrayUtilities,
  cuda_compat,
  cudaPackagesConfig,
  lib,
}:
prevAttrs: {
  propagatedBuildOutputs =
    prevAttrs.propagatedBuildOutputs or [ ]
    ++ [ "static" ] # required by CMake
    ++ lib.optionals (!cudaPackagesConfig.hasJetsonCudaCapability || cuda_compat == null) [
      "stubs"
    ];

  # When cuda_compat is available, propagate it.
  # NOTE: `cuda_compat` can be disabled by setting the package to `null`. This is useful in cases where
  # the host OS has a recent enough CUDA driver that the compatibility library isn't needed.
  propagatedBuildInputs =
    prevAttrs.propagatedBuildInputs or [ ]
    ++ lib.optionals (cudaPackagesConfig.hasJetsonCudaCapability && cuda_compat != null) [
      cuda_compat
    ];

  postPatch =
    prevAttrs.postPatch or ""
    # Patch the `cudart` package config files so they reference lib
    + ''
      while IFS= read -r -d $'\0' path; do
        nixLog "patching $path"
        sed -i \
          -e "s|^cudaroot\s*=.*\$||" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cudart-*.pc' -print0)
    ''
    # Patch the `cuda` package config files so they reference stubs
    # TODO: Will this always pull in the stubs output and cause its setup hook to be executed?
    + ''
      while IFS= read -r -d $'\0' path; do
        nixLog "patching $path"
        sed -i \
          -e "s|^cudaroot\s*=.*\$||" \
          -e "s|^libdir\s*=.*/lib\$|libdir=''${!outputStubs:?}/lib/stubs|" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cuda-*.pc' -print0)
    '';

  # NOTE: cuda_cudart.dev depends on :
  # - crt/host_config.h, which is from cuda_nvcc.dev
  # - nv/target, which is from cuda_cccl.dev
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
    prevAttrs.postFixup or ""
    # Install the setup hook
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
        --subst-var-by cudartStubLibDir "''${!outputStubs:?}/lib" \
        --subst-var-by driverLibDir "${addDriverRunpath.driverLink}/lib"

      nixLog "installing cudaCudartRunpathFixupHook.bash dependencies to ''${!outputStubs:?}/nix-support/propagated-host-host-deps"
      printWords \
        "${arrayUtilities.occursInArray}" \
        "${arrayUtilities.getRunpathEntries}" \
        >>"''${!outputStubs:?}/nix-support/propagated-host-host-deps"
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
