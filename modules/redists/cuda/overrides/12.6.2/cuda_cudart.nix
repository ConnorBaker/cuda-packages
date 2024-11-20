{
  addDriverRunpath,
  cuda_cccl,
  cuda_nvcc,
  cudaAtLeast,
  flags,
  lib,
}:
let
  inherit (lib.attrsets) getOutput;
  inherit (lib.lists) elem optionals;
  inherit (lib.strings) optionalString;
in
finalAttrs: prevAttrs: {
  # Include the static libraries as well since CMake needs them during the configure phase.
  propagatedBuildOutputs =
    prevAttrs.propagatedBuildOutputs
    ++ [ "static" ]
    # cuda_compat provides its own libcuda.so, so we need to make sure it's not shadowed.
    ++ optionals (!flags.isJetsonBuild) [ "stubs" ];

  # The libcuda stub's pkg-config doesn't follow the general pattern:
  postPatch =
    prevAttrs.postPatch or ""
    + ''
      while IFS= read -r -d $'\0' path; do
        sed -i \
          -e "s|^libdir\s*=.*/lib\$|libdir=''${stubs:?}/lib/stubs|" \
          -e "s|^Libs\s*:\(.*\)\$|Libs: \1 -Wl,-rpath,${addDriverRunpath.driverLink}/lib|" \
          "$path"
      done < <(find -iname 'cuda-*.pc' -print0)
    '';

  postInstall =
    prevAttrs.postInstall or ""
    # NOTE: We can't patch a single output with overrideAttrs, so we need to use nix-support.
    # NOTE: Make sure to guard against the assert running when the package isn't available.
    + optionalString finalAttrs.finalPackage.meta.available (
      ''
        mkdir -p "''${!outputInclude}/nix-support"
      ''
      # cuda_cudart.dev depends on crt/host_config.h, which is from cuda_nvcc.dev.
      + optionalString cuda_nvcc.meta.available ''
        printWords "${getOutput "include" cuda_nvcc}" >> "''${!outputInclude}/nix-support/propagated-build-inputs"
      ''
      # cuda_cuadrt.dev has include/cuda_fp16.h which requires cuda_cccl.dev's include/nv/target
      + optionalString (cudaAtLeast "12.0") ''
        printWords "${getOutput "include" cuda_cccl}" >> "''${!outputInclude}/nix-support/propagated-build-inputs"
      ''
    )
    # Namelink may not be enough, add a soname.
    # Cf. https://gitlab.kitware.com/cmake/cmake/-/issues/25536
    # NOTE: Add symlinks inside $stubs/lib so autoPatchelfHook can find them -- it doesn't recurse into subdirectories.
    + optionalString (elem "stubs" finalAttrs.outputs) ''
      pushd "$stubs/lib/stubs"
      [[ -f libcuda.so && ! -f libcuda.so.1 ]] && ln -s libcuda.so libcuda.so.1
      for file in *
      do
        ln -s "$PWD/$file" "$PWD/../$file"
      done
      popd
    '';
}
