{
  cudaAtLeast,
  cudaStdenv,
  cudaOlder,
  lib,
  nvccHook,
  stdenv,
}:
finalAttrs: prevAttrs: {
  # The nvcc and cicc binaries contain hard-coded references to /usr
  allowFHSReferences = true;

  # Entries here will be in nativeBuildInputs when cuda_nvcc is in nativeBuildInputs
  propagatedBuildInputs = prevAttrs.propagatedBuildInputs or [ ] ++ [
    nvccHook
    cudaStdenv.cc
  ];

  # Patch the nvcc.profile.
  # Syntax:
  # - `=` for assignment,
  # - `?=` for conditional assignment,
  # - `+=` to "prepend",
  # - `=+` to "append".

  # Cf. https://web.archive.org/web/20220912081901/https://developer.download.nvidia.com/compute/DevZone/docs/html/C/doc/nvcc.pdf

  # We set all variables with the lowest priority (=+), but we do force
  # nvcc to use the fixed backend toolchain. Cf. comments in
  # backend-stdenv.nix

  # As an example, here's the nvcc.profile for CUDA 11.8-12.4 (yes, that is a leading newline):

  #
  # TOP              = $(_HERE_)/..
  #
  # NVVMIR_LIBRARY_DIR = $(TOP)/$(_NVVM_BRANCH_)/libdevice
  #
  # LD_LIBRARY_PATH += $(TOP)/lib:
  # PATH            += $(TOP)/$(_NVVM_BRANCH_)/bin:$(_HERE_):
  #
  # INCLUDES        +=  "-I$(TOP)/$(_TARGET_DIR_)/include" $(_SPACE_)
  #
  # LIBRARIES        =+ $(_SPACE_) "-L$(TOP)/$(_TARGET_DIR_)/lib$(_TARGET_SIZE_)/stubs" "-L$(TOP)/$(_TARGET_DIR_)/lib$(_TARGET_SIZE_)"
  #
  # CUDAFE_FLAGS    +=
  # PTXAS_FLAGS     +=

  # And here's the nvcc.profile for CUDA 12.5:

  #
  # TOP              = $(_HERE_)/..
  #
  # CICC_PATH        = $(TOP)/nvvm/bin
  # CICC_NEXT_PATH   = $(TOP)/nvvm-next/bin
  # NVVMIR_LIBRARY_DIR = $(TOP)/nvvm/libdevice
  #
  # LD_LIBRARY_PATH += $(TOP)/lib:
  # PATH            += $(CICC_PATH):$(_HERE_):
  #
  # INCLUDES        +=  "-I$(TOP)/$(_TARGET_DIR_)/include" $(_SPACE_)
  #
  # LIBRARIES        =+ $(_SPACE_) "-L$(TOP)/$(_TARGET_DIR_)/lib$(_TARGET_SIZE_)/stubs" "-L$(TOP)/$(_TARGET_DIR_)/lib$(_TARGET_SIZE_)"
  #
  # CUDAFE_FLAGS    +=
  # PTXAS_FLAGS     +=

  postInstall =
    prevAttrs.postInstall or ""
    + lib.optionalString finalAttrs.finalPackage.meta.available (
      # Always move the nvvm directory to the bin output.
      ''
        moveToOutput "nvvm" "''${!outputBin:?}"
        mv --verbose --no-clobber "''${!outputBin:?}/nvvm/lib64" "''${!outputBin:?}/nvvm/lib"
      ''
      # Unconditional patching to remove the use of $(_TARGET_SIZE_) since we don't use lib64 in Nixpkgs
      + ''
        nixLog 'removing $(_TARGET_SIZE_) from nvcc.profile'
        substituteInPlace "''${!outputBin:?}/bin/nvcc.profile" \
          --replace-fail \
            '$(_TARGET_SIZE_)' \
            ""
      ''
      # Unconditional patching to switch to the correct include paths.
      # NOTE: _TARGET_DIR_ appears to be used for the target architecture, which is relevant for cross-compilation.
      + ''
        nixLog "patching nvcc.profile to use the correct include paths"
        substituteInPlace "''${!outputBin:?}/bin/nvcc.profile" \
          --replace-fail \
            '$(TOP)/$(_TARGET_DIR_)/include' \
            "''${!outputInclude:?}/include"
      ''
      # Fixup the nvcc.profile to use the correct paths for the backend compiler and NVVM.
      + (
        let
          # TODO: Should we also patch the LIBRARIES line's use of $(TOP)/$(_TARGET_DIR_)?
          oldNvvmDir = lib.concatStringsSep "/" (
            [ "$(TOP)" ]
            ++ lib.optionals (cudaOlder "12.5") [ "$(_NVVM_BRANCH_)" ]
            ++ lib.optionals (cudaAtLeast "12.5") [ "nvvm" ]
          );
          newNvvmDir = ''''${!outputBin:?}/nvvm'';
        in
        # Unconditional patching to switch to the correct NVVM paths.
        # NOTE: In our replacement substitution, we use double quotes to allow for variable expansion.
        # NOTE: We use a trailing slash only on the NVVM directory replacement to prevent partial matches.
        ''
          nixLog "patching nvcc.profile to use the correct NVVM paths"
          substituteInPlace "''${!outputBin:?}/bin/nvcc.profile" \
            --replace-fail \
              '${oldNvvmDir}/' \
              "${newNvvmDir}/"
        ''
        # Add the dependency on cudaStdenv.cc and the new NVVM directories to the nvcc.profile.
        # NOTE: Escape the dollar sign in the variable expansion to prevent early expansion.
        + ''
          nixLog "adding cudaStdenv.cc and ${newNvvmDir} to nvcc.profile"
          cat << EOF >> "''${!outputBin:?}/bin/nvcc.profile"

          # Fix a compatible backend compiler
          PATH += "${cudaStdenv.cc}/bin":

          # Expose the split-out nvvm
          LIBRARIES =+ \$(_SPACE_) "-L${newNvvmDir}/lib"
          INCLUDES =+ \$(_SPACE_) "-I${newNvvmDir}/include"
          EOF
        ''
      )
    );

  passthru = prevAttrs.passthru or { } // {
    inherit cudaStdenv;

    nvccHostCCMatchesStdenvCC = cudaStdenv.cc == stdenv.cc;

    redistBuilderArg = prevAttrs.passthru.redistBuilderArg or { } // {
      # NOTE: May need to restrict cuda_nvcc to a single output to avoid breaking consumers which expect NVCC
      # to be within a single directory structure. This happens partly because NVCC is also home to NVVM.
      outputs = [
        "out"
        "bin"
        "dev"
        "include"
        "static"
      ];
    };
  };

  meta = prevAttrs.meta or { } // {
    mainProgram = "nvcc";
  };
}
