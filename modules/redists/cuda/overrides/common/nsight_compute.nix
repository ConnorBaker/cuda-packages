{
  autoreconfHook,
  cuda_cudart,
  cuda_nvml_dev,
  cudaPackagesConfig,
  dbus,
  e2fsprogs,
  fetchpatch,
  fetchzip,
  fontconfig,
  gst_all_1,
  kdePackages,
  lib,
  libdeflate,
  libjpeg,
  libssh,
  libxkbcommon,
  nspr,
  nss,
  pkg-config,
  qt6Packages,
  rdma-core,
  stdenv,
  ucx,
  xcb-util-cursor,
  xorg,
  xz,
  zlib,
}:
let
  inherit (cudaPackagesConfig) hostRedistSystem;
  inherit (lib.attrsets) getLib getOutput;
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

  # Most of this is taken directly from
  # https://github.com/NixOS/nixpkgs/blob/ea4c80b39be4c09702b0cb3b42eab59e2ba4f24b/pkgs/development/libraries/libtiff/default.nix
  libtiff_4_4 = stdenv.mkDerivation (finalAttrs: {
    pname = "libtiff";
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

    postPatch = ''
      mv VERSION VERSION.txt
    '';

    outputs = [
      "bin"
      "dev"
      "dev_private"
      "out"
      "man"
      "doc"
    ];

    postFixup = ''
      moveToOutput include/tif_dir.h $dev_private
      moveToOutput include/tif_config.h $dev_private
      moveToOutput include/tiffiop.h $dev_private
    '';

    # If you want to change to a different build system, please make
    # sure cross-compilation works first!
    nativeBuildInputs = [
      autoreconfHook
      pkg-config
    ];

    buildInputs = [ libdeflate ];

    propagatedBuildInputs = [
      libjpeg
      xz
      zlib
    ];

    enableParallelBuilding = true;

    doCheck = true;
  });
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
        nixLog "removing unsupported ''${kind}s for host redist system ${hostRedistSystem}"
        if [[ ! -d "$kind" ]]; then
          nixLog "directory $kind does not exist, skipping"
          continue
        fi
        pushd "$kind"
        for dir in *; do
          case "${hostRedistSystem}" in
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
          *) nixLogError "unknown host redist system: ${hostRedistSystem}" && exit 1;;
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
    prevAttrs.buildInputs or [ ]
    ++ [
      (getOutput "stubs" cuda_cudart)
      (getLib dbus)
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
    ++ optionals stdenv.hostPlatform.isAarch64 [
      qtpositioning
      qtwebengine
    ]
    ++ optionals (finalAttrs.version == "2023.2.2.3") [
      gst-plugins-base
      gstreamer
      libtiff_4_4 # libtiff.so.5
    ]
    ++ optionals (finalAttrs.version == "2025.1.0.14") [
      cuda_nvml_dev
      libtiff_4_4 # libtiff.so.5
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

  passthru = prevAttrs.passthru or { } // {
    inherit libtiff_4_4;
  };

  meta = prevAttrs.meta or { } // {
    mainProgram = "ncu";
  };
}
