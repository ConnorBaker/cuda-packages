{
  boost178,
  cuda_cudart,
  cuda_nvml_dev,
  cudaPackages,
  e2fsprogs,
  fetchpatch,
  fetchzip,
  gst_all_1,
  lib,
  libtiff,
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
  inherit (lib.attrsets) getOutput;
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

  # Most of this is taken directly from
  # https://github.com/NixOS/nixpkgs/blob/ea4c80b39be4c09702b0cb3b42eab59e2ba4f24b/pkgs/development/libraries/libtiff/default.nix
  libtiff_4_5 = libtiff.overrideAttrs (
    finalAttrs: _: {
      version = "4.4.0";
      src = fetchzip {
        url = "https://download.osgeo.org/libtiff/tiff-${finalAttrs.version}.tar.gz";
        hash = "sha256-NiqxTgfXIvUsVMu9nTJULVulfcFm+Z2IBMc6mNgwnsY=";
      };
      patches = [
        # FreeImage needs this patch
        (fetchpatch {
          name = "headers.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/headers.patch";
          hash = "sha256-+eaPCdWUyGC6rfEd54/8PqqGZ4hg8GpH75/NZgTKTt4=";
        })
        # libc++abi 11 has an `#include <version>`, this picks up files name
        # `version` in the project's include paths
        (fetchpatch {
          name = "rename-version.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/rename-version.patch";
          hash = "sha256-ykefUIyTqcAWX9b/CtqPsd82AsUFZZGhiL+9UmEcvU8=";
        })
        (fetchpatch {
          name = "CVE-2022-34526.patch";
          url = "https://gitlab.com/libtiff/libtiff/-/commit/275735d0354e39c0ac1dc3c0db2120d6f31d1990.patch";
          hash = "sha256-faKsdJjvQwNdkAKjYm4vubvZvnULt9zz4l53zBFr67s=";
        })
        (fetchpatch {
          name = "CVE-2022-2953.patch";
          url = "https://gitlab.com/libtiff/libtiff/-/commit/48d6ece8389b01129e7d357f0985c8f938ce3da3.patch";
          hash = "sha256-h9hulV+dnsUt/2Rsk4C1AKdULkvweM2ypIJXYQ3BqQU=";
        })
        (fetchpatch {
          name = "CVE-2022-3626.CVE-2022-3627.CVE-2022-3597.patch";
          url = "https://gitlab.com/libtiff/libtiff/-/commit/236b7191f04c60d09ee836ae13b50f812c841047.patch";
          excludes = [ "doc/tools/tiffcrop.rst" ];
          hash = "sha256-L2EMmmfMM4oEYeLapO93wvNS+HlO0yXsKxijXH+Wuas=";
        })
        (fetchpatch {
          name = "CVE-2022-3598.CVE-2022-3570.patch";
          url = "https://gitlab.com/libtiff/libtiff/-/commit/cfbb883bf6ea7bedcb04177cc4e52d304522fdff.patch";
          hash = "sha256-SLq2+JaDEUOPZ5mY4GPB6uwhQOG5cD4qyL5o9i8CVVs=";
        })
        (fetchpatch {
          name = "CVE-2022-3970.patch";
          url = "https://gitlab.com/libtiff/libtiff/-/commit/227500897dfb07fb7d27f7aa570050e62617e3be.patch";
          hash = "sha256-pgItgS+UhMjoSjkDJH5y7iGFZ+yxWKqlL7BdT2mFcH0=";
        })
        (fetchpatch {
          name = "4.4.0-CVE-2022-48281.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/4.4.0-CVE-2022-48281.patch";
          hash = "sha256-i/Gw8MvqlOwy2CupJrX7Ec1yS9xg+19CM9kKlxvvvYE=";
        })
        (fetchpatch {
          name = "4.4.0-CVE-2023-0800.CVE-2023-0801.CVE-2023-0802.CVE-2023-0803.CVE-2023-0804.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/4.4.0-CVE-2023-0800.CVE-2023-0801.CVE-2023-0802.CVE-2023-0803.CVE-2023-0804.patch";
          hash = "sha256-yKMI8AJALEV/qjJk5MhIOj+x2nHMzDvnrroWRjTcqP4=";
        })
        (fetchpatch {
          name = "4.4.0-CVE-2023-0795.CVE-2023-0796.CVE-2023-0797.CVE-2023-0798.CVE-2023-0799.prerequisite-0.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/4.4.0-CVE-2023-0795.CVE-2023-0796.CVE-2023-0797.CVE-2023-0798.CVE-2023-0799.prerequisite-0.patch";
          hash = "sha256-+MHoxuzJj7ADjKz4zl4YO+e1IdzphXa451h+sRZ7gys=";
        })
        (fetchpatch {
          name = "4.4.0-CVE-2023-0795.CVE-2023-0796.CVE-2023-0797.CVE-2023-0798.CVE-2023-0799.prerequisite-1.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/4.4.0-CVE-2023-0795.CVE-2023-0796.CVE-2023-0797.CVE-2023-0798.CVE-2023-0799.prerequisite-1.patch";
          hash = "sha256-+UHvo03zlmwxu1s5oRCK9SudgjcjV/iaMKW4SY/wy4E=";
        })
        (fetchpatch {
          name = "4.4.0-CVE-2023-0795.CVE-2023-0796.CVE-2023-0797.CVE-2023-0798.CVE-2023-0799.patch";
          url = "https://raw.githubusercontent.com/NixOS/nixpkgs/release-22.11/pkgs/development/libraries/libtiff/4.4.0-CVE-2023-0795.CVE-2023-0796.CVE-2023-0797.CVE-2023-0798.CVE-2023-0799.patch";
          hash = "sha256-tMZ/ci2am9XNmD889XdjNnBUKNiN3/toMP1+QWQx+wE=";
        })
        (fetchpatch {
          name = "CVE-2022-4645.patch";
          url = "https://gitlab.com/libtiff/libtiff/-/commit/f00484b9519df933723deb38fff943dc291a793d.patch";
          sha256 = "sha256-sFVi5BY/L8WisrtTThkux1Gw2x0UrurnSlv4KkEvw3w=";
        })
      ];
    }
  );
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
      (ucx.override { inherit cudaPackages; })
      boost178
      cuda_cudart
      e2fsprogs
      gst-plugins-base
      gstreamer
      libtiff_4_5 # libtiff.so.5
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
      qtwayland
      qtwebengine
      rdma-core
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

  passthru = prevAttrs.passthru or { } // {
    inherit libtiff_4_5;
  };
}
