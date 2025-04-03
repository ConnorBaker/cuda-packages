# NOTE: All fixups must be at least binary functions to avoid callPackage adding override attributes.
{
  autoAddDriverRunpath,
  autoPatchelfHook,
  config,
  cudaHook,
  cudaMajorMinorVersion,
  cudaMajorVersion,
  cudaNamePrefix,
  cudaPackagesConfig,
  cudaRunpathFixupHook,
  lib,
  markForCudaToolkitRootHook,
  stdenv,
}:
let
  inherit (cudaPackagesConfig) hasJetsonCudaCapability hostRedistSystem;
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
  inherit (lib.strings) concatMapStringsSep;
  inherit (lib.trivial) flip id warnIfNot;

  hasAnyTrueValue = attrs: any id (attrValues attrs);
in
# We need finalAttrs, so even if prevAttrs isn't used we still need to take it as an argument (see https://noogle.dev/f/lib/fixedPoints/toExtension).
finalAttrs: _:
let
  inherit (finalAttrs.passthru) redistBuilderArg;
  hasOutput = flip elem finalAttrs.outputs;
in
{
  __structuredAttrs = true;
  strictDeps = true;

  # Name should be prefixed by cudaNamePrefix to create more descriptive path names.
  name = "${cudaNamePrefix}-${finalAttrs.pname}-${finalAttrs.version}";

  # NOTE: Even though there's no actual buildPhase going on here, the derivations of the
  # redistributables are sensitive to the compiler flags provided to stdenv. The patchelf package
  # is sensitive to the compiler flags provided to stdenv, and we depend on it. As such, we are
  # also sensitive to the compiler flags provided to stdenv.
  pname = redistBuilderArg.packageName;
  version = redistBuilderArg.releaseVersion;

  # We should only have the output `out` when `src` is null.
  # lists.intersectLists iterates over the second list, checking if the elements are in the first list.
  # As such, the order of the output is dictated by the order of the second list.
  outputs =
    if finalAttrs.src == null then
      [ "out" ]
    else
      intersectLists redistBuilderArg.outputs finalAttrs.passthru.expectedOutputs;

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
  # NOTE: We must set outputInclude carefully to ensure we get fallback to other outputs if the `include` output
  # doesn't exist.
  outputInclude =
    if hasOutput "include" then
      "include"
    else if hasOutput "dev" then
      "dev"
    else
      "out";

  outputStubs = if hasOutput "stubs" then "stubs" else "out";

  # src :: null | Derivation
  src = redistBuilderArg.releaseSource;

  postUnpack = ''
    nixLog "checking for $NIX_BUILD_TOP/$sourceRoot/lib/${cudaMajorVersion}..."
    if [[ -d "$NIX_BUILD_TOP/$sourceRoot/lib/${cudaMajorVersion}" ]]; then
      pushd "$NIX_BUILD_TOP/$sourceRoot" >/dev/null
      mv \
        --verbose \
        --no-clobber \
        "$PWD/lib/${cudaMajorVersion}" \
        "$PWD/lib-new"
      rm --recursive "$PWD/lib" || {
        nixErrorLog "could not delete $PWD/lib: $(ls -laR "$PWD/lib")"
        exit 1
      }
      mv \
        --verbose \
        --no-clobber \
        "$PWD/lib-new" \
        "$PWD/lib"
      popd >/dev/null
    fi
  '';

  postPatch =
    # Pkg-config's setup hook expects configuration files in $out/share/pkgconfig
    ''
      for path in "$NIX_BUILD_TOP/$sourceRoot"/{pkg-config,pkgconfig}; do
        [[ -d $path ]] || continue
        mkdir -p "$NIX_BUILD_TOP/$sourceRoot/share/pkgconfig"
        mv \
          --verbose \
          --no-clobber \
          --target-directory "$NIX_BUILD_TOP/$sourceRoot/share/pkgconfig" \
          "$path"/*
        rm --recursive --dir "$path" || {
          nixErrorLog "$path contains non-empty directories: $(ls -laR "$path")"
          exit 1
        }
      done
      unset -v path
    ''
    # Rewrite FHS paths with store paths
    # NOTE: output* fall back to out if the corresponding output isn't defined.
    + ''
      for pc in "$NIX_BUILD_TOP/$sourceRoot"/share/pkgconfig/*.pc; do
        nixLog "patching $pc"
        sed -i \
          -e "s|^cudaroot\s*=.*\$|cudaroot=''${!outputDev:?}|" \
          -e "s|^libdir\s*=.*/lib\$|libdir=''${!outputLib:?}/lib|" \
          -e "s|^includedir\s*=.*/include\$|includedir=''${!outputDev:?}/include|" \
          "$pc"
      done
      unset -v pc
    ''
    # Generate unversioned names.
    # E.g. cuda-11.8.pc -> cuda.pc
    + ''
      for pc in "$NIX_BUILD_TOP/$sourceRoot"/share/pkgconfig/*-"${cudaMajorMinorVersion}.pc"; do
        nixLog "creating unversioned symlink for $pc"
        ln -s "$(basename "$pc")" "''${pc%-${cudaMajorMinorVersion}.pc}".pc
      done
      unset -v pc
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
      markForCudaToolkitRootHook
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
          template = pattern: ''
            moveToOutput "${pattern}" "${"$" + output}"
          '';
          patterns = finalAttrs.passthru.outputToPatterns.${output} or [ ];
        in
        concatMapStringsSep "\n" template patterns;
    in
    # Pre-install hook
    ''
      runHook preInstall
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
      nixLog "checking for FHS references..."
      firstMatches="$(grep --max-count=5 --recursive --exclude=LICENSE /usr/ "''${outputPaths[@]}")" || true
      if [[ -n "$firstMatches" ]]; then
        nixErrorLog "Detected the references to /usr: $firstMatches"
        exit 1
      fi
      unset -v firstMatches
    fi

    for output in $(getAllOutputNames); do
      [[ "''${!output:?}" == "out" ]] && continue
      nixLog "checking if "''${!output:?}" contains non nix-support directories..."
      case "$(find "''${!output:?}" -mindepth 1 -maxdepth 1 -type d)" in
      "" | "''${!output:?}/nix-support/")
        nixErrorLog "output $output is empty (excluding nix-support)!"
        nixErrorLog "this typically indicates a failure in packaging or moveToOutput ordering"
        ls -laR "''${!output:?}"
        exit 1
        ;;
      *) ;;
      esac
    done
    unset -v output

    if [[ -d "''${!outputLib:?}/lib" ]]; then
      nixLog "checking for .so files in ''${!outputLib:?}/lib..."
      case "$(find "''${!outputLib:?}/lib" -mindepth 1 -maxdepth 1 -name '*.so*')" in
      "")
        nixErrorLog "directory ''${!outputLib:?}/lib contains no .so files!"
        nixErrorLog "this typically indicates a failure in packaging or raising lib subpaths"
        ls -laR "''${!outputLib:?}/lib"
        exit 1
        ;;
      *) ;;
      esac
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
    + ''
      for output in $(getAllOutputNames); do
        # Skip out and dev outputs
        [[ ''${output:?} == "out" ]] && continue
        # Propagate the other components to the out output
        nixLog "adding output ''${output:?} to output out's propagated-build-inputs"
        printWords "''${!output:?}" >> "$out/nix-support/propagated-build-inputs"
      done
      unset -v output
    '';

  passthru = {
    redistBuilderArg = {
      # The name of the redistributable to which this package belongs.
      redistName = builtins.throw "redistBuilderArg.redistName must be set";

      # The full package name, for use in meta.description
      # e.g., "CXX Core Compute Libraries"
      releaseName = builtins.throw "redistBuilderArg.releaseName must be set";

      # The package version
      # e.g., "12.2.140"
      releaseVersion = builtins.throw "redistBuilderArg.releaseVersion must be set";

      # The path to the license, or null
      # e.g., "cuda_cccl/LICENSE.txt"
      licensePath = builtins.throw "redistBuilderArg.licensePath must be set";

      # The short name of the package
      # e.g., "cuda_cccl"
      packageName = builtins.throw "redistBuilderArg.packageName must be set";

      # Package source, or null
      releaseSource = builtins.throw "redistBuilderArg.releaseSource must be set";

      # The outputs provided by this package.
      outputs = builtins.throw "redistBuilderArg.outputs must be set";

      # TODO(@connorbaker): Document these
      supportedRedistSystems = builtins.throw "redistBuilderArg.supportedRedistSystems must be set";
      supportedNixSystems = builtins.throw "redistBuilderArg.supportedNixSystems must be set";
    };

    # Order is important here so we use a list.
    expectedOutputs = [
      "out"
      "doc"
      "sample"
      "python"
      "bin"
      "dev"
      "include"
      "lib"
      "static"
      "stubs"
    ];

    # Traversed in the order of the outputs speficied in outputs;
    # entries are skipped if they don't exist in outputs.
    outputToPatterns = {
      bin = [ "bin" ];
      dev = [
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
    description = "${redistBuilderArg.releaseName}. By downloading and using the packages you accept the terms and conditions of the ${finalAttrs.meta.license.shortName}";
    sourceProvenance = [ sourceTypes.binaryNativeCode ];
    broken =
      warnIfNot config.cudaSupport
        "CUDA support is disabled and you are building a CUDA package (${finalAttrs.finalPackage.name}); expect breakage!"
        (hasAnyTrueValue finalAttrs.passthru.brokenConditions);
    platforms = redistBuilderArg.supportedNixSystems;
    badPlatforms = optionals (hasAnyTrueValue finalAttrs.passthru.badPlatformsConditions) (unique [
      stdenv.buildPlatform.system
      stdenv.hostPlatform.system
      stdenv.targetPlatform.system
    ]);
    license = licenses.nvidiaCudaRedist // {
      url =
        let
          licensePath =
            if redistBuilderArg.licensePath != null then
              redistBuilderArg.licensePath
            else
              "${redistBuilderArg.packageName}/LICENSE.txt";
        in
        "https://developer.download.nvidia.com/compute/${redistBuilderArg.redistName}/redist/${licensePath}";
    };
    maintainers = teams.cuda.members;
  };
}
