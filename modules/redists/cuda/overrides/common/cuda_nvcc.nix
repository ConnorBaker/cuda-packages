{
  cudaAtLeast,
  cudaConfig,
  cudaMajorMinorPatchVersion,
  cudaMajorMinorVersion,
  cudaOlder,
  lib,
  nvccHook,
  pkgs,
  stdenv,
  stdenvAdapters,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep optionalString;

  # This is what nvcc uses as a backend,
  # and it has to be an officially supported one (e.g. gcc11 for cuda11).
  #
  # It, however, propagates current stdenv's libstdc++ to avoid "GLIBCXX_* not found errors"
  # when linked with other C++ libraries.
  # E.g. for cudaPackages_11_8 we use gcc11 with gcc12's libstdc++
  # Cf. https://github.com/NixOS/nixpkgs/pull/218265 for context
  nvccStdenv =
    let
      defaultNvccHostCompilerMajorVersion =
        cudaConfig.data.nvccCompatibilities.${cudaMajorMinorVersion}.gcc.maxMajorVersion;
      defaultNvccHostStdenv = pkgs."gcc${defaultNvccHostCompilerMajorVersion}Stdenv";
      nvccConfig = cudaConfig.cudaPackages.${cudaMajorMinorPatchVersion}.nvcc;
      nvccHostStdenv =
        if nvccConfig.hostStdenv != null then nvccConfig.hostStdenv else defaultNvccHostStdenv;
    in
    stdenvAdapters.useLibsFrom stdenv nvccHostStdenv;
in
finalAttrs: prevAttrs: {
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

  # NOTE(@connorbaker):
  # While the postInstall phase is fairly gnarly and repetitive, it's necessary to ensure we're able to add
  # dependencies to *specific* outputs generated as by the multiple-output setup hook. Barring this method of
  # manipulating the files in `nix-support` in the respective outputs, I'm not sure there is a way to do per-output
  # manipulation of dependencies. If there is, I'd love to hear about it!
  postInstall =
    prevAttrs.postInstall or ""
    + optionalString finalAttrs.finalPackage.meta.available (
      # Always move the nvvm directory to the bin output.
      ''
        moveToOutput "nvvm" "''${!outputBin}"
        nixLog "moving nvvm/lib64 to nvvm/lib"
        mv "''${!outputBin}/nvvm/lib64" "''${!outputBin}/nvvm/lib"
      ''
      # Create a directory for our manual propagation.
      + ''
        mkdir -p "''${!outputBin}/nix-support"
      ''
      # Add nvccHook to the propagatedBuildInputs of the bin output.
      # NOTE(@connorbaker):
      # Though it might seem odd or counter-intuitive to add the setup hook to `propagatedBuildInputs` instead of
      # `propagatedNativeBuildInputs`, it is necessary! If you move the setup hook from `propagatedBuildInputs` to
      # `propagatedNativeBuildInputs`, it stops being propagated to downstream packages during their build because
      # setup hooks in `propagatedNativeBuildInputs` are not designed to affect the runtime or build environment of
      # dependencies; they are only meant to affect the build environment of the package that directly includes them.
      + ''
        nixLog "adding nvccHook to $outputBin's propagatedBuildInputs"
        printWords "${nvccHook}" >> "''${!outputBin}/nix-support/propagated-build-inputs"
      ''
      # Add the dependency on nvccStdenv.cc to the nvcc.profile and native-propagated-build-inputs.
      # NOTE: No need to add a dependency on `newNvvmDir` since it's already in the bin output.
      + ''
        nixLog "adding nvccStdenv.cc to $outputBin's nativePropagatedBuildInputs"
        printWords "${nvccStdenv.cc}" >> "''${!outputBin}/nix-support/native-propagated-build-inputs"
      ''
      # Unconditional patching to remove the use of $(_TARGET_SIZE_) since we don't use lib64 in Nixpkgs
      + ''
        nixLog "removing $(_TARGET_SIZE_) from nvcc.profile"
        substituteInPlace "''${!outputBin}/bin/nvcc.profile" \
          --replace-fail \
            '$(_TARGET_SIZE_)' \
            ""
      ''
      # Unconditional patching to switch to the correct include paths.
      # NOTE: _TARGET_DIR_ appears to be used for the target architecture, which is relevant for cross-compilation.
      + ''
        nixLog "patching nvcc.profile to use the correct include paths"
        substituteInPlace "''${!outputBin}/bin/nvcc.profile" \
          --replace-fail \
            '$(TOP)/$(_TARGET_DIR_)/include' \
            "''${!outputInclude}/include"
      ''
      # Add the dependency on the include output to the nvcc.profile.
      + ''
        nixLog "adding $outputInclude's include output to $outputBin's propagatedBuildInputs"
        printWords "''${!outputInclude}" >> "''${!outputBin}/nix-support/native-propagated-build-inputs"
      ''
      # Fixup the nvcc.profile to use the correct paths for the backend compiler and NVVM.
      + (
        let
          # TODO: Should we also patch the LIBRARIES line's use of $(TOP)/$(_TARGET_DIR_)?
          oldNvvmDir = concatStringsSep "/" (
            [ "$(TOP)" ]
            ++ optionals (cudaOlder "12.5") [ "$(_NVVM_BRANCH_)" ]
            ++ optionals (cudaAtLeast "12.5") [ "nvvm" ]
          );
          newNvvmDir = ''''${!outputBin}/nvvm'';
        in
        # Unconditional patching to switch to the correct NVVM paths.
        # NOTE: In our replacement substitution, we use double quotes to allow for variable expansion.
        # NOTE: We use a trailing slash only on the NVVM directory replacement to prevent partial matches.
        ''
          nixLog "patching nvcc.profile to use the correct NVVM paths"
          substituteInPlace "''${!outputBin}/bin/nvcc.profile" \
            --replace-fail \
              '${oldNvvmDir}/' \
              "${newNvvmDir}/"
        ''
        # Add the dependency on nvccStdenv.cc and the new NVVM directories to the nvcc.profile.
        # NOTE: Escape the dollar sign in the variable expansion to prevent early expansion.
        + ''
          nixLog "adding nvccStdenv.cc and ${newNvvmDir} to nvcc.profile"
          cat << EOF >> "''${!outputBin}/bin/nvcc.profile"

          # Fix a compatible backend compiler
          PATH += "${nvccStdenv.cc}/bin":

          # Expose the split-out nvvm
          LIBRARIES =+ \$(_SPACE_) "-L${newNvvmDir}/lib"
          INCLUDES =+ \$(_SPACE_) "-I${newNvvmDir}/include"
          EOF
        ''
      )
    );

  # The nvcc and cicc binaries contain hard-coded references to /usr
  allowFHSReferences = true;

  passthru = prevAttrs.passthru or { } // {
    inherit nvccStdenv;
    nvccHostCCMatchesStdenvCC = nvccStdenv.cc == stdenv.cc;
  };

  meta = prevAttrs.meta or { } // {
    mainProgram = "nvcc";
  };
}
