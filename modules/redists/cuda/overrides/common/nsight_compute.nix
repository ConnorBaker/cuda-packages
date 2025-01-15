{
  cuda_cudart,
  cudaConfig,
  cudaStdenv,
  dbus,
  e2fsprogs,
  fontconfig,
  gst_all_1,
  kdePackages,
  lib,
  libssh,
  libxkbcommon,
  nsight_systems,
  nspr,
  nss,
  qt6Packages,
  rdma-core,
  ucx,
  xcb-util-cursor,
  xorg,
}:
let
  inherit (cudaConfig) hostRedistArch;
  inherit (lib.attrsets) getOutput;
  inherit (lib.lists) optionals;
  inherit (lib.strings) optionalString;
  inherit (gst_all_1)
    gst-plugins-base
    gstreamer
    ;
  inherit (qt6Packages)
    qtpositioning
    qtwebengine
    ;
  inherit (xorg)
    libxcb
    libXcomposite
    libXcursor
    libXdamage
    libxkbfile
    libXrandr
    libxshmfence
    libXtst
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    xcbutilwm
    ;
in
finalAttrs: prevAttrs: {
  allowFHSReferences = true;

  outputs = [
    "out"
    "doc"
  ];

  # NOTE: While you can try to replace the vendored libs, I (@connorbaker) would strongly recommend against it.
  # Nixpkgs provides newer to much newer versions of the libraries NVIDIA builds against.
  # You'll get hard errors to debug about GLIBC and Qt and other nightmarish things.
  # My advice? Provide it with Xorg and get out of its way.
  # If you do try to go that route, note that (at the time of this writing) Qt setup hooks don't play well with
  # structuredAttrs or multiple outputs.

  postUnpack =
    prevAttrs.postUnpack or ""
    + optionalString (finalAttrs.version == "2023.2.2.3") ''
      nixLog "Moving subdirectories of nsight-compute to $sourceRoot"
      mv "''${sourceRoot:?}/nsight-compute/2023.2.2/"* "''${sourceRoot:?}/"
      nixLog "Removing directory nsight-compute"
      rmdir "''${sourceRoot:?}/nsight-compute/2023.2.2" "''${sourceRoot:?}/nsight-compute"
    '';

  postPatch =
    prevAttrs.postPatch or ""
    + ''
      for kind in host target; do
        nixLog "removing unsupported ''${kind}s for host redist arch ${hostRedistArch}"
        if [[ ! -d "$kind" ]]; then
          nixLog "directory $kind does not exist, skipping"
          continue
        fi
        pushd "$kind"
        for dir in *; do
          case "${hostRedistArch}" in
          linux-aarch64|linux-sbsa)
            case "$dir" in
            linux-*-a64) nixLog "keeping $dir";;
            *) nixLog "removing $dir" && rm -r "$dir";;
            esac
            ;;
          linux-x86_64)
            case "$dir" in
            linux-*-x64|target-linux-x64) nixLog "keeping $dir";;
            *) nixLog "removing $dir" && rm -r "$dir";;
            esac
            ;;
          *) nixLogError "unknown host redist arch: ${hostRedistArch}" && exit 1;;
          esac
        done
        popd
      done

      patchShebangs .

      nixLog "removing vendored Mesa components"
      rm -rf host/*/Mesa
    '';

  dontWrapQtApps = true;

  buildInputs =
    prevAttrs.buildInputs
    ++ [
      (getOutput "stubs" cuda_cudart)
      dbus.lib
      e2fsprogs
      fontconfig
      kdePackages.qtwayland
      libssh
      libxkbcommon
      nspr
      nss
      rdma-core
      ucx
      xcb-util-cursor
      # xorg
      libxcb
      libXcomposite
      libXcursor
      libXdamage
      libxkbfile
      libXrandr
      libxshmfence
      libXtst
      xcbutilimage
      xcbutilkeysyms
      xcbutilrenderutil
      xcbutilwm
    ]
    ++ optionals cudaStdenv.hostPlatform.isAarch64 [
      qtpositioning
      qtwebengine
    ]
    ++ optionals (finalAttrs.version == "2023.2.2.3") [
      gst-plugins-base
      gstreamer
      nsight_systems.passthru.libtiff_4_5 # libtiff.so.5
    ];

  postInstall =
    prevAttrs.postInstall or ""
    + ''
      moveToOutput docs "''${doc:?}"
      if [[ -e "$out/ncu" && -e "$out/ncu-ui" ]]; then
        nixLog "symlinking executables to bin dir"
        mkdir -p "$out/bin"
        # TODO(@connorbaker): This should fail if there is not exactly one host/target.
        ln -snf "$out/target/"linux-*"/ncu" "$out/bin/ncu"
        ln -snf "$out/host/"linux-*"/ncu-ui" "$out/bin/ncu-ui"
        rm "$out/ncu" "$out/ncu-ui"
      fi
    '';

  meta = prevAttrs.meta or { } // {
    mainProgram = "ncu";
  };
}
