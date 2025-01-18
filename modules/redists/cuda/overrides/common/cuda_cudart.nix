{
  addDriverRunpath,
  cuda_cccl,
  cuda_compat,
  cuda_nvcc,
  flags,
  lib,
}:
let
  inherit (lib.attrsets) getOutput;
  inherit (lib.lists) optionals;
  inherit (lib.strings) optionalString;
in
prevAttrs: {
  # Include the static libraries as well since CMake needs them during the configure phase.
  propagatedBuildOutputs = prevAttrs.propagatedBuildOutputs or [ ] ++ [
    "static"
    "stubs"
  ];

  # When cuda_compat is available, propagate it.
  # `cuda_compat` provides its own `libcuda.so`, but it requires driver libraries only available in the runtime.
  # So, we always use the stubs provided by `cuda_cudart` and rely on `autoAddCudaCompatRunpath` to add `cuda_compat`'s
  # `libcuda.so` to the RPATH of our libraries.
  # Since the libraries in `cuda_compat` are all under the `compat` directory, we don't run into issues where there are
  # multiple versions of `libcuda.so` in the environment.
  # NOTE: `cuda_compat` can be disabled by setting the package to `null`. This is useful in cases where
  # the host OS has a recent enough CUDA driver that the compatibility library isn't needed.
  propagatedBuildInputs =
    prevAttrs.propagatedBuildInputs or [ ]
    ++ optionals (flags.isJetsonBuild && cuda_compat != null) [ cuda_compat ];

  postPatch =
    prevAttrs.postPatch or ""
    # Patch the `cudart` package config files so they reference lib
    + ''
      while IFS= read -r -d $'\0' path; do
        nixLog "patching $path"
        sed -i \
          -e "s|^cudaroot\s*=.*\$||" \
          -e "s|^libdir\s*=.*/lib\$|libdir=''${!outputLib:?}/lib|" \
          -e "s|^includedir\s*=.*/include\$|includedir=''${!outputInclude:?}/include|" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cudart-*.pc' -print0)
    ''
    # Patch the `cuda` package config files so they reference stubs
    + ''
      while IFS= read -r -d $'\0' path; do
        nixLog "patching $path"
        sed -i \
          -e "s|^cudaroot\s*=.*\$||" \
          -e "s|^libdir\s*=.*/lib\$|libdir=''${stubs:?}/lib/stubs|" \
          -e "s|^includedir\s*=.*/include\$|includedir=''${!outputInclude:?}/include|" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cuda-*.pc' -print0)
    '';

  postInstall =
    prevAttrs.postInstall or ""
    # NOTE: We can't patch a single output with overrideAttrs, so we need to use nix-support.
    + ''
      mkdir -p "''${!outputInclude}/nix-support"
    ''
    # cuda_cudart.dev depends on crt/host_config.h, which is from cuda_nvcc.dev.
    + optionalString cuda_nvcc.meta.available ''
      nixLog "adding cuda_nvcc's include output to $outputInclude's propagatedBuildInputs"
      printWords "${getOutput "include" cuda_nvcc}" >> "''${!outputInclude}/nix-support/propagated-build-inputs"
    ''
    # cuda_cuadrt.dev has include/cuda_fp16.h which requires cuda_cccl.dev's include/nv/target
    + ''
      nixLog "adding cuda_cccl's include output to $outputInclude's propagatedBuildInputs"
      printWords "${getOutput "include" cuda_cccl}" >> "''${!outputInclude}/nix-support/propagated-build-inputs"
    ''
    # Namelink may not be enough, add a soname.
    # Cf. https://gitlab.kitware.com/cmake/cmake/-/issues/25536
    # NOTE: Add symlinks inside $stubs/lib so autoPatchelfHook can find them -- it doesn't recurse into subdirectories.
    + ''
      pushd "$stubs/lib/stubs"
      if [[ -f libcuda.so && ! -f libcuda.so.1 ]]; then
        nixLog "creating versioned symlink for libcuda.so stub"
        ln -sr libcuda.so libcuda.so.1
      fi
      nixLog "creating symlinks for stubs in lib directory"
      ln -srt "$stubs/lib/" *.so *.so.*
      popd
    '';
}
