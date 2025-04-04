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

  # Required for the hook.
  inherit cudaMajorMinorVersion cudaMajorVersion;

  # We do need some other phases, like configurePhase, so the multiple-output setup hook works.
  dontBuild = true;

  nativeBuildInputs = [
    ./redistBuilderHook.bash
    autoPatchelfHook
    # This hook will make sure libcuda can be found
    # in typically /lib/opengl-driver by adding that
    # directory to the rpath of all ELF binaries.
    # Check e.g. with `patchelf --print-rpath path/to/my/binary
    autoAddDriverRunpath
    markForCudaToolkitRootHook
  ];

  propagatedBuildInputs = [ cudaHook ];

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
  # NOTE: installPhase is not moved into the builder hook because we do a lot of Nix templating.
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

  passthru = {
    redistBuilderArg = {
      # The name of the redistributable to which this package belongs.
      redistName = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.redistName";

      # The full package name, for use in meta.description
      # e.g., "CXX Core Compute Libraries"
      releaseName = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.releaseName";

      # The package version
      # e.g., "12.2.140"
      releaseVersion = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.releaseVersion";

      # The path to the license, or null
      # e.g., "cuda_cccl/LICENSE.txt"
      licensePath = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.licensePath";

      # The short name of the package
      # e.g., "cuda_cccl"
      packageName = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.packageName";

      # Package source, or null
      releaseSource = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.releaseSource";

      # The outputs provided by this package.
      outputs = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.outputs";

      # TODO(@connorbaker): Document these
      supportedRedistSystems = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.supportedRedistSystems";
      supportedNixSystems = builtins.throw "redist-builder: ${finalAttrs.name} did not set passthru.redistBuilderArg.supportedNixSystems";
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
        isRedistSystemSbsaExplicitlySupported = elem "linux-sbsa" redistBuilderArg.supportedRedistSystems;
        isRedistSystemAarch64ExplicitlySupported = elem "linux-aarch64" redistBuilderArg.supportedRedistSystems;
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
