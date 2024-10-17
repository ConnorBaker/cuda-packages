{
  boost178,
  cuda_cudart,
  cuda-lib,
  cudaOlder,
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
  inherit (lib.attrsets) getBin;
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
        rm -r "$path"
      done
    ''
    + ''
      patchShebangs nsight-systems
    '';

  nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ wrapQtAppsHook ];

  buildInputs = prevAttrs.buildInputs ++ [
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
  ];

  postInstall =
    # 1. Move dependencies of nsys, nsys-ui binaries to bin output
    # 2. Fix paths in wrapper scripts
    let
      majorMinorPatchVersion = cuda-lib.utils.majorMinorPatch version;
    in
    prevAttrs.postInstall or ""
    + ''
      moveToOutput 'nsight-systems/${majorMinorPatchVersion}/host-linux-*' "''${!outputBin}"
      moveToOutput 'nsight-systems/${majorMinorPatchVersion}/target-linux-*' "''${!outputBin}"
      substituteInPlace $bin/bin/nsys $bin/bin/nsys-ui \
        --replace-fail 'nsight-systems-#VERSION_RSPLIT#' nsight-systems/${majorMinorPatchVersion}
      for qtlib in $bin/nsight-systems/${majorMinorPatchVersion}/host-linux-x64/Plugins/*/libq*.so; do
        qtdir=$(basename $(dirname $qtlib))
        filename=$(basename $qtlib)
        for qtpkgdir in ${
          lib.concatMapStringsSep " " (pkg: pkg.outPath) [
            qtbase
            qtimageformats
            qtsvg
            qtwayland
          ]
        }; do
          if [ -e $qtpkgdir/lib/qt-6/plugins/$qtdir/$filename ]; then
            ln -snf $qtpkgdir/lib/qt-6/plugins/$qtdir/$filename $qtlib
          fi
        done
      done
    '';

  autoPatchelfIgnoreMissingDeps =
    prevAttrs.autoPatchelfIgnoreMissingDeps
    ++ optionals (versionAtLeast version "2024.5.1.113") [
      # Provided by the driver.
      "libnvidia-ml.so.1"
    ];
}
