{
  cuda_cudart,
  cudaConfig,
  e2fsprogs,
  fetchpatch,
  fetchzip,
  gst_all_1,
  lib,
  libtiff,
  qt6Packages,
  rdma-core,
  ucx,
}:
let
  inherit (cudaConfig) hostRedistArch;
  inherit (lib.attrsets) getBin getOutput;
  inherit (lib.lists) optionals;
  inherit (lib.strings) versionAtLeast;
  inherit (gst_all_1) gst-plugins-base;
  inherit (qt6Packages) qtwayland qtwebview wrapQtAppsHook;
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
  nativeBuildInputs = prevAttrs.nativeBuildInputs ++ [ wrapQtAppsHook ];
  buildInputs =
    prevAttrs.buildInputs
    ++ [ qtwebview ]
    ++ optionals (versionAtLeast version "2022.4") [
      (getBin qtwayland)
      e2fsprogs
      libtiff_4_5
      rdma-core
      ucx
    ]
    ++ optionals (versionAtLeast version "2023.1") [
      (getOutput "stubs" cuda_cudart)
      gst-plugins-base
    ];
  # We don't have the means to ensure autoPatchelf finds the correct library from the correct package set
  # when trying to patch cross-platform libs, so we ensure the only hosts/targets available have the same architecture.
  postInstall =
    prevAttrs.postInstall or ""
    + ''
      for kind in host target; do
        nixLog "removing unsupported ''${kind}s for host redist arch ${hostRedistArch}"
        if [[ ! -d "$out/$kind" ]]; then
          nixLog "directory $out/$kind does not exist, skipping"
          continue
        fi
        pushd "$out/$kind"
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
    '';
}
