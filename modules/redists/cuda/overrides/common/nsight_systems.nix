{
  boost178,
  cuda_cudart,
  cuda_nvml_dev,
  e2fsprogs,
  gst_all_1,
  lib,
  nss,
  numactl,
  pulseaudio,
  qt6Packages,
  rdma-core,
  ucx,
  wayland,
  xorg,
}:
let
  inherit (lib.attrsets) getBin getOutput;
  inherit (lib.lists) optionals;
  inherit (lib.strings) versionAtLeast;
  inherit (gst_all_1)
    gst-plugins-base
    gstreamer
    ;
  inherit (qt6Packages)
    qtbase
    qtdeclarative
    qtimageformats
    qtpositioning
    qtscxml
    qtsvg
    qttools
    qtwayland
    qtwebengine
    wrapQtAppsHook
    ;
  inherit (xorg)
    libXcursor
    libXdamage
    libXrandr
    libXtst
    ;

  qtWaylandPlugins = "${getBin qtwayland}/${qtbase.qtPluginPrefix}";
in
finalAttrs: prevAttrs:
let
  inherit (finalAttrs) version;
in
{
  allowFHSReferences = true;

  outputs = prevAttrs.outputs or [ ] ++ [ "doc" ];

  # An ad hoc replacement for
  # https://github.com/ConnorBaker/cuda-redist-find-features/issues/11
  env = prevAttrs.env or { } // {
    rmPatterns = toString [
      "nsight-systems/*/*/lib{arrow,jpeg}*"
      "nsight-systems/*/*/lib{ssl,ssh,crypto}*"
      "nsight-systems/*/*/libboost*"
      "nsight-systems/*/*/libexec"
      "nsight-systems/*/*/libQt6*"
      "nsight-systems/*/*/libstdc*"
      "nsight-systems/*/*/Mesa"
      "nsight-systems/*/*/python/bin/python"
    ];
  };

  postPatch =
    prevAttrs.postPatch or ""
    + ''
      for path in $rmPatterns; do
        nixLog "deleting files matching $path"
        rm -r "$path"
      done
      patchShebangs nsight-systems
    '';

  nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ wrapQtAppsHook ];

  buildInputs =
    prevAttrs.buildInputs
    ++ [
      boost178
      cuda_cudart
      e2fsprogs
      gst-plugins-base
      gstreamer
      libXcursor
      libXdamage
      libXrandr
      libXtst
      nss
      numactl
      pulseaudio
      qtbase
      qtdeclarative
      qtimageformats
      qtpositioning
      qtscxml
      qtsvg
      qttools
      qtWaylandPlugins
      qtwebengine
      rdma-core
      ucx
      wayland
    ]
    ++ optionals (versionAtLeast version "2024") [
      (getOutput "stubs" cuda_nvml_dev)
    ];

  postInstall =
    # 1. Move dependencies of nsys, nsys-ui binaries to bin output
    # 2. Fix paths in wrapper scripts
    let
      majorMinorPatchVersion = lib.cuda.utils.majorMinorPatch version;
    in
    prevAttrs.postInstall or ""
    # Patch bin output
    + ''
      moveToOutput 'nsight-systems/${majorMinorPatchVersion}/host-linux-*' "$bin"
      moveToOutput 'nsight-systems/${majorMinorPatchVersion}/target-linux-*' "$bin"
      nixLog "patching nsight-systems wrapper scripts"
      substituteInPlace "$bin/bin/nsys" "$bin/bin/nsys-ui" \
        --replace-fail \
          "nsight-systems-#VERSION_RSPLIT#" \
          "nsight-systems/${majorMinorPatchVersion}"
      for qtlib in "$bin/nsight-systems/${majorMinorPatchVersion}/host-linux-x64/Plugins"/*/libq*.so; do
        qtdir="$(basename "$(dirname "$qtlib")")"
        filename="$(basename "$qtlib")"
        for qtpkgdir in ${
          lib.concatMapStringsSep " " (pkg: pkg.outPath) [
            qtbase
            qtimageformats
            qtsvg
            qtwayland
          ]
        }; do
          if [[ -e "$qtpkgdir/${qtbase.qtPluginPrefix}/$qtdir/$filename" ]]; then
            nixLog "linking $qtpkgdir/${qtbase.qtPluginPrefix}/$qtdir/$filename to $qtlib"
            ln -snf "$qtpkgdir/${qtbase.qtPluginPrefix}/$qtdir/$filename" "$qtlib"
          fi
        done
      done
    ''
    # Move docs to doc output
    + ''
      moveToOutput 'nsight-systems/${majorMinorPatchVersion}/docs' "$doc"
    ''
    # Remove symlinks in default output. Do so by binary name, so we get an error from rmdir if the binary directory
    # isn't empty.
    + ''
      nixLog "removing symlinks in default output"
      rm "$out/nsight-systems/${majorMinorPatchVersion}/bin/"nsys*
      rmdir "$out/nsight-systems/${majorMinorPatchVersion}/bin"
    '';
}
