{
  lib,
  markForCudatoolkitRootHook,
  requireFile,
  stdenv,
  unzip,
}:
let
  inherit (lib) maintainers teams;
  inherit (lib.versions) majorMinor;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  preferLocalBuild = true;
  allowSubstitutes = false;

  # Name of downloaded file is upper-case for some reason.
  pname = "Video_Codec_SDK";
  version = "12.2.72";

  src = requireFile {
    url = "https://developer.nvidia.com/downloads/designworks/video-codec-sdk/secure/${majorMinor finalAttrs.version}/${finalAttrs.pname}_${finalAttrs.version}.zip";
    hash = "sha256-/D4FzSoZT7k+Lp8R+IRPZ4QB9N9cnQF2MtaMmS6Bim4=";
  };

  nativeBuildInputs = [
    markForCudatoolkitRootHook
    unzip
  ];

  dontConfigure = true;

  dontBuild = true;

  installPhase =
    let
      cpuName = stdenv.hostPlatform.parsed.cpu.name;
    in
    ''
      runHook preInstall

      mkdir -p share

      nixLog "moving Doc to share/doc"
      mv Doc share/doc
      nixLog "moving top-level documents to share/doc"
      mv *.pdf *.txt share/doc/

      nixLog "moving Samples to share/samples"
      mv Samples share/samples

      nixLog "renaming Interface to include"
      mv Interface include

      nixLog "moving Lib/linux/stubs/${cpuName} to lib/stubs"
      mkdir -p lib
      mv "Lib/linux/stubs/${cpuName}" lib/stubs

      pushd "lib/stubs"
      for libname in libnvcuvid libnvidia-encode; do
        if [[ -f "$libname.so" && ! -f "$libname.so.1" ]]; then
          nixLog "creating versioned symlink for $libname.so stub"
          ln -sr "$libname.so" "$libname.so.1"
        fi
      done
      nixLog "creating symlinks for stubs in lib directory"
      ln -srt .. *.so *.so.*
      popd

      nixLog "deleting Lib directory"
      rm -r Lib

      nixLog "installing to $out"
      mkdir -p "$out"
      cp -r . "$out"

      runHook postInstall
    '';

  meta = {
    description = "NVIDIA Video Codec SDK";
    license = {
      fullName = "NVIDIA VIDEO CODEC SDK LICENSE AGREEMENT";
      url = "https://developer.nvidia.com/nvidia-video-codec-sdk-license-agreement";
      free = false;
    };
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    hydraPlatforms = [ ];
    maintainers = (with maintainers; [ connorbaker ]) ++ teams.cuda.members;
  };
})
