# General callPackage-supplied arguments
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  config,
  cudaLib,
  cudaMajorMinorVersion,
  cudaMajorMinorPatchVersion,
  cudaPackagesConfig,
  cudaRunpathFixupHook,
  lib,
  markForCudatoolkitRootHook,
  cudaHook,
  stdenv,
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability hostRedistSystem;
  inherit (cudaLib.utils) getLibPath;
  inherit (lib)
    licenses
    sourceTypes
    teams
    ;
  inherit (lib.attrsets) attrValues optionalAttrs;
  inherit (lib.lists)
    any
    elem
    findFirstIndex
    intersectLists
    optionals
    tail
    unique
    ;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (lib.trivial) id;
in
# Builder-specific arguments
{
  # src :: null | Derivation
  src,
  # packageInfo :: PackageInfo
  packageInfo,
  # Short package name (e.g., "cuda_cccl")
  # packageName : String
  packageName,
  # redistName :: String
  redistName,
  # releaseInfo :: ReleaseInfo
  releaseInfo,
  # supportedNixSystems :: List String
  supportedNixSystems,
  # supportedRedistSystems :: List RedistSystem
  supportedRedistSystems,
}:
let
  # Order is important here so we use a list.
  possibleOutputs = [
    "bin"
    "include"
    "lib"
    "static"
    "dev"
    "doc"
    "sample"
    "python"
    "stubs"
  ];
  # lists.intersectLists iterates over the second list, checking if the elements are in the first list.
  # As such, the order of the output is dictated by the order of the second list.
  componentOutputs = intersectLists packageInfo.features.outputs possibleOutputs;
  # Some packages provide support for multiple CUDA versions in the lib directory.
  libPath = getLibPath cudaMajorMinorPatchVersion packageInfo.features.cudaVersionsInLib;
in
stdenv.mkDerivation (
  finalAttrs:
  let
    isBadPlatform = any id (attrValues finalAttrs.passthru.badPlatformsConditions);
    isBroken = any id (attrValues finalAttrs.passthru.brokenConditions);
  in
  {
    # NOTE: Even though there's no actual buildPhase going on here, the derivations of the
    # redistributables are sensitive to the compiler flags provided to stdenv. The patchelf package
    # is sensitive to the compiler flags provided to stdenv, and we depend on it. As such, we are
    # also sensitive to the compiler flags provided to stdenv.
    pname = packageName;
    inherit (releaseInfo) version;

    # We should only have the output `out` when `src` is null.
    outputs = [ "out" ] ++ optionals (src != null) componentOutputs;

    # NOTE: Because the `dev` output is special in Nixpkgs -- make-derivation.nix uses it as the default if
    # it is present -- we must ensure that it brings in the expected dependencies. For us, this means that `dev`
    # should include `bin`, `include`, and `lib` -- `static` is notably absent because it is quite large.
    # We do not include `stubs`, as a number of packages contain stubs for libraries they already ship with!
    # Only a few, like cuda_cudart, actually provide stubs for libraries we're missing.
    # As such, these packages should override propagatedBuildOutputs to add `stubs`.
    propagatedBuildOutputs = intersectLists [
      "bin"
      "include"
      "lib"
    ] finalAttrs.outputs;

    # We have a separate output for include files; don't use the dev output.
    outputInclude = "include";

    # src :: null | Derivation
    inherit src;

    postPatch =
      # Pkg-config's setup hook expects configuration files in $out/share/pkgconfig
      ''
        for path in pkg-config pkgconfig; do
          [[ -d "$path" ]] || continue
          mkdir -p share/pkgconfig
          nixLog "moving contents of $path to share/pkgconfig"
          mv "$path"/* share/pkgconfig/
          rmdir "$path"
        done
      ''
      # Rewrite FHS paths with store paths
      # NOTE: output* fall back to out if the corresponding output isn't defined.
      + ''
        for pc in share/pkgconfig/*.pc; do
          nixLog "patching $pc"
          sed -i \
            -e "s|^cudaroot\s*=.*\$|cudaroot=''${!outputDev}|" \
            -e "s|^libdir\s*=.*/lib\$|libdir=''${!outputLib}/lib|" \
            -e "s|^includedir\s*=.*/include\$|includedir=''${!outputDev}/include|" \
            "$pc"
        done
      ''
      # Generate unversioned names.
      # E.g. cuda-11.8.pc -> cuda.pc
      + ''
        for pc in share/pkgconfig/*-"${cudaMajorMinorVersion}.pc"; do
          nixLog "creating unversioned symlink for $pc"
          ln -s "$(basename "$pc")" "''${pc%-${cudaMajorMinorVersion}.pc}".pc
        done
      '';

    # We do need some other phases, like configurePhase, so the multiple-output setup hook works.
    dontBuild = true;

    nativeBuildInputs =
      [
        autoPatchelfHook
        # This hook will make sure libcuda can be found
        # in typically /lib/opengl-driver by adding that
        # directory to the rpath of all ELF binaries.
        # Check e.g. with `patchelf --print-rpath path/to/my/binary
        autoAddDriverRunpath
        markForCudatoolkitRootHook
      ]
      ++ optionals (finalAttrs.pname != "cuda_compat" && finalAttrs.pname != "cuda_cudart") [
        cudaRunpathFixupHook
      ];

    propagatedBuildInputs =
      [ cudaHook ]
      # cudaRunpathFixupHook depends on cuda_cudart and cuda_compat, so we cannot include it in those.
      ++ optionals (finalAttrs.pname != "cuda_compat" && finalAttrs.pname != "cuda_cudart") [
        cudaRunpathFixupHook
      ];

    buildInputs = [
      # autoPatchelfHook will search for a libstdc++ and we're giving it
      # one that is compatible with the rest of nixpkgs, even when
      # nvcc forces us to use an older gcc
      # NB: We don't actually know if this is the right thing to do
      # NOTE: Not all packages actually need this, but it's easier to just add it than create overrides for nearly all
      # of them.
      stdenv.cc.cc.lib
    ];

    # Picked up by autoPatchelf
    # Needed e.g. for libnvrtc to locate (dlopen) libnvrtc-builtins
    appendRunpaths = [ "$ORIGIN" ];

    # NOTE: We don't need to check for dev or doc, because those outputs are handled by
    # the multiple-outputs setup hook.
    # NOTE: moveToOutput operates on all outputs:
    # https://github.com/NixOS/nixpkgs/blob/2920b6fc16a9ed5d51429e94238b28306ceda79e/pkgs/build-support/setup-hooks/multiple-outputs.sh#L105-L107
    installPhase =
      let
        mkMoveToOutputCommand =
          output:
          let
            template = pattern: ''moveToOutput "${pattern}" "${"$" + output}"'';
            patterns = finalAttrs.passthru.outputToPatterns.${output} or [ ];
          in
          concatMapStringsSep "\n" template patterns;
      in
      # Pre-install hook
      ''
        runHook preInstall
      ''
      # Handle the existence of libPath, which requires us to re-arrange the lib directory.
      + optionalString (libPath != null) ''
        full_lib_path="lib/${libPath}"
        if [[ ! -d "$full_lib_path" ]]; then
          nixErrorLog "$full_lib_path does not exist"
          nixErrorLog "only found the following in lib: $(find lib/ -mindepth 1 -maxdepth 1)"
          nixErrorLog "this release might not support your CUDA version"
          exit 1
        fi
        nixLog "making $full_lib_path the root of lib"
        mv "$full_lib_path" lib_new
        rm -r lib
        mv lib_new lib
      ''
      # Create the primary output, out, and move the other outputs into it.
      + ''
        mkdir -p "$out"
        nixLog "moving tree to output out"
        mv * "$out"
      ''
      # Move the outputs into their respective outputs.
      + ''
        ${concatMapStringsSep "\n" mkMoveToOutputCommand (tail finalAttrs.outputs)}
      ''
      # Post-install hook
      + ''
        runHook postInstall
      '';

    doInstallCheck = true;
    allowFHSReferences = false;
    postInstallCheck = ''
      if [[ -z "''${allowFHSReferences-}" ]]; then
        nixLog "Checking for FHS references"
        firstMatches="$(grep --max-count=5 --recursive --exclude=LICENSE /usr/ "''${outputPaths[@]}")" || true
        if [[ -n "$firstMatches" ]]; then
          nixErrorLog "Detected the references to /usr: $firstMatches"
          exit 1
        fi
      fi
    '';

    # TODO(@connorbaker): https://github.com/NixOS/nixpkgs/issues/323126.
    # _multioutPropagateDev() currently expects a space-separated string rather than an array.
    # Because it is a postFixup hook, we correct it in preFixup.
    preFixup = ''
      nixLog "converting propagatedBuildOutputs to a space-separated string"
      export propagatedBuildOutputs="''${propagatedBuildOutputs[@]}"
    '';

    postFixup =
      # The `out` output should largely be empty save for nix-support/propagated-build-inputs.
      # In effect, this allows us to make `out` depend on all the other components.
      ''
        mkdir -p "$out/nix-support"
      ''
      # NOTE: We must use printWords to ensure the output is a single line.
      # See addPkg in ./pkgs/build-support/buildenv/builder.pl -- it splits on spaces.
      # TODO: The comment in the for-loop says to skip out and dev, but the code only skips out.
      # Since `dev` depends on `out` by default, wouldn't this cause a cycle?
      + ''
        for output in $(getAllOutputNames); do
          # Skip out and dev outputs
          [[ "$output" == "out" ]] && continue
          # Propagate the other components to the out output
          nixLog "adding output $output to output out's propagated-build-inputs"
          printWords "''${!output}" >> "$out/nix-support/propagated-build-inputs"
        done
      '';

    passthru = {
      # Traversed in the order of the outputs speficied in outputs;
      # entries are skipped if they don't exist in outputs.
      outputToPatterns = {
        bin = [ "bin" ];
        dev = [
          "share/pkgconfig"
          "**/*.pc"
          "**/*.cmake"
        ];
        include = [ "include" ];
        lib = [
          "lib"
          "lib64"
        ];
        static = [ "**/*.a" ];
        sample = [ "samples" ];
        python = [ "**/*.whl" ];
        stubs = [
          "stubs"
          "lib/stubs"
        ];
      };

      inherit supportedRedistSystems;

      # Useful for introspecting why something went wrong. Maps descriptions of why the derivation would be marked as
      # broken on have badPlatforms include the current platform.

      # brokenConditions :: AttrSet Bool
      # Sets `meta.broken = true` if any of the conditions are true.
      # Example: Broken on a specific version of CUDA or when a dependency has a specific version.
      # NOTE: Do not use this when a broken condition means evaluation will fail! For example, if
      # a package is missing and is required for the build -- that should go in badPlatformsConditions,
      # because attempts to access attributes on the package will cause evaluation errors.
      brokenConditions = {
        # Typically this results in the static output being empty, as all libraries are moved
        # back to the lib output.
        "lib output follows static output" =
          let
            libIndex = findFirstIndex (x: x == "lib") null finalAttrs.outputs;
            staticIndex = findFirstIndex (x: x == "static") null finalAttrs.outputs;
          in
          libIndex != null && staticIndex != null && libIndex > staticIndex;
      };

      # badPlatformsConditions :: AttrSet Bool
      # Sets `meta.badPlatforms = meta.platforms` if any of the conditions are true.
      # Example: Broken on a specific system when some condition is met, like targeting Jetson or
      # a required package missing.
      # NOTE: Use this when a broken condition means evaluation can fail!
      badPlatformsConditions =
        let
          isRedistSystemSbsaExplicitlySupported = elem "linux-sbsa" finalAttrs.passthru.supportedRedistSystems;
          isRedistSystemAarch64ExplicitlySupported = elem "linux-aarch64" finalAttrs.passthru.supportedRedistSystems;
        in
        {
          "CUDA support is not enabled" = !config.cudaSupport;
          "Platform is not supported" =
            finalAttrs.src == null || hostRedistSystem == "unsupported" || finalAttrs.meta.platforms == [ ];
        }
        // optionalAttrs (stdenv.hostPlatform.isAarch64 && stdenv.hostPlatform.isLinux) {
          "aarch64-linux support is limited to linux-sbsa (server ARM devices) which is not the current target" =
            isRedistSystemSbsaExplicitlySupported
            && !isRedistSystemAarch64ExplicitlySupported
            && hasJetsonCudaCapability;
          "aarch64-linux support is limited to linux-aarch64 (Jetson devices) which is not the current target" =
            !isRedistSystemSbsaExplicitlySupported
            && isRedistSystemAarch64ExplicitlySupported
            && !hasJetsonCudaCapability;
        };
    };

    meta = {
      description = "${releaseInfo.name}. By downloading and using the packages you accept the terms and conditions of the ${finalAttrs.meta.license.shortName}";
      sourceProvenance = [ sourceTypes.binaryNativeCode ];
      broken = isBroken;
      platforms = supportedNixSystems;
      badPlatforms = optionals isBadPlatform (unique [
        stdenv.buildPlatform.system
        stdenv.hostPlatform.system
        stdenv.targetPlatform.system
      ]);
      license = licenses.nvidiaCudaRedist // {
        url =
          let
            licensePath =
              if releaseInfo.licensePath != null then releaseInfo.licensePath else "${packageName}/LICENSE.txt";
          in
          "https://developer.download.nvidia.com/compute/${redistName}/redist/${licensePath}";
      };
      maintainers = teams.cuda.members;
    };
  }
)
