{
  config, # Evaluated module attribute from cuda-modules
  cudaMajorMinorVersion,
  cudaMajorVersion,
  cudaOlder,
  cudaAtLeast,
  cuda_gdb ? null,
  runPatches ? [ ],
  autoPatchelfHook,
  autoAddDriverRunpath,
  addOpenGLRunpath,
  alsa-lib,
  curlMinimal,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glibc,
  gst_all_1,
  gtk2,
  lib,
  libxkbcommon,
  libkrb5,
  krb5,
  makeWrapper,
  markForCudatoolkitRootHook,
  ncurses5,
  numactl,
  nss,
  patchelf,
  perl,
  python3, # FIXME: CUDAToolkit 10 may still need python27
  pulseaudio,
  setupCudaHook,
  stdenv,
  backendStdenv, # E.g. gcc11Stdenv, set in extension.nix
  unixODBC,
  wayland,
  xorg,
  zlib,
  libglut,
  libGLU,
  libsForQt5,
  libtiff,
  qt6Packages,
  qt6,
  rdma-core,
  ucx,
  rsync,
  libglvnd,
}:

let
  # Version info for the classic cudatoolkit packages that contain everything that is in redist.
  release = config.data.cudatoolkitRunfileReleases.${cudaMajorMinorVersion};
in

backendStdenv.mkDerivation (finalAttrs: {
  name = "cuda${cudaMajorMinorVersion}-${finalAttrs.pname}";
  pname = "cudatoolkit-legacy-runfile";
  inherit (release) version;
  inherit runPatches;

  dontPatchELF = true;
  dontStrip = true;

  src = fetchurl { inherit (release) hash url; };

  outputs = [
    "out"
    "lib"
    "doc"
  ];

  nativeBuildInputs =
    [
      perl
      makeWrapper
      rsync
      addOpenGLRunpath
      autoPatchelfHook
      autoAddDriverRunpath
      markForCudatoolkitRootHook
    ]
    ++ lib.optionals (cudaOlder "11") [ libsForQt5.wrapQtAppsHook ]
    ++ lib.optionals (cudaAtLeast "11.8") [ qt6Packages.wrapQtAppsHook ];
  propagatedBuildInputs = [ setupCudaHook ];
  buildInputs =
    lib.optionals (cudaOlder "11") [
      libsForQt5.qt5.qtwebengine
      libglut
      libGLU
    ]
    ++ [
      # To get $GDK_PIXBUF_MODULE_FILE via setup-hook
      gdk-pixbuf

      # For autoPatchelf
      ncurses5
      expat
      python3
      zlib
      glibc
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXt
      xorg.libXtst
      xorg.libXi
      xorg.libXext
      xorg.libXdamage
      xorg.libxcb
      xorg.xcbutilimage
      xorg.xcbutilrenderutil
      xorg.xcbutilwm
      xorg.xcbutilkeysyms
      pulseaudio
      libxkbcommon
      libkrb5
      krb5
      gtk2
      glib
      fontconfig
      freetype
      numactl
      nss
      unixODBC
      alsa-lib
      wayland
      libglvnd
    ]
    ++ lib.optionals (cudaAtLeast "11.8") [
      (lib.getLib libtiff)
      qt6Packages.qtwayland
      rdma-core
      (ucx.override { enableCuda = false; }) # Avoid infinite recursion
      xorg.libxshmfence
      xorg.libxkbfile
    ]
    ++ lib.optionals (cudaAtLeast "12") (
      map lib.getLib ([
        # Used by `/target-linux-x64/CollectX/clx` and `/target-linux-x64/CollectX/libclx_api.so` for:
        # - `libcurl.so.4`
        curlMinimal

        # Used by `/host-linux-x64/Scripts/WebRTCContainer/setup/neko/server/bin/neko`
        gst_all_1.gstreamer
        gst_all_1.gst-plugins-base
      ])
      ++ (with qt6; [
        qtmultimedia
        qttools
        qtpositioning
        qtscxml
        qtsvg
        qtwebchannel
        qtwebengine
      ])
    )
    # Add any missing packages required by the CUDA GDB redist, which should be transferrable.
    ++ lib.optionals (cuda_gdb != null) cuda_gdb.passthru.fixups.cudatoolkit-legacy-runfile.buildInputs;

  # Prepended to runpaths by autoPatchelf.
  # The order inherited from older rpath preFixup code
  runtimeDependencies = [
    (placeholder "lib")
    (placeholder "out")
    "${placeholder "out"}/nvvm"
    # NOTE: use the same libstdc++ as the rest of nixpkgs, not from backendStdenv
    "${lib.getLib stdenv.cc.cc}/lib64"
    "${placeholder "out"}/jre/lib/amd64/jli"
    "${placeholder "out"}/lib64"
    "${placeholder "out"}/nvvm/lib64"
  ];

  autoPatchelfIgnoreMissingDeps =
    [
      # This is the hardware-dependent userspace driver that comes from
      # nvidia_x11 package. It must be deployed at runtime in
      # /run/opengl-driver/lib or pointed at by LD_LIBRARY_PATH variable, rather
      # than pinned in runpath
      "libcuda.so.1"

      # The krb5 expression ships libcom_err.so.3 but cudatoolkit asks for the
      # older
      # This dependency is asked for by target-linux-x64/CollectX/RedHat/x86_64/libssl.so.10
      # - do we even want to use nvidia-shipped libssl?
      "libcom_err.so.2"
    ]
    ++ lib.optionals (cudaOlder "10.1") [
      # For Cuda 10.0, nVidia also shipped a jre implementation which needed
      # two old versions of ffmpeg which are not available in nixpkgs
      "libavcodec.so.54"
      "libavcodec.so.53"
      "libavformat.so.54"
      "libavformat.so.53"
    ];

  preFixup =
    lib.optionalString (cudaAtLeast "10.1" && cudaOlder "11") ''
      ${lib.getExe' patchelf "patchelf"} $out/targets/*/lib/libnvrtc.so --add-needed libnvrtc-builtins.so
    ''
    + lib.optionalString (cudaAtLeast "11") ''
      ${lib.getExe' patchelf "patchelf"} $out/lib64/libnvrtc.so --add-needed libnvrtc-builtins.so
    '';

  unpackPhase =
    ''
      sh $src --keep --noexec
    ''
    + lib.optionalString (cudaOlder "10.1") ''
      cd pkg/run_files
      sh cuda-linux*.run --keep --noexec
      sh cuda-samples*.run --keep --noexec
      mv pkg ../../$(basename $src)
      cd ../..
      rm -rf pkg

      for patch in $runPatches; do
        sh $patch --keep --noexec
        mv pkg $(basename $patch)
      done
    '';

  installPhase =
    ''
      runHook preInstall
      mkdir $out
    ''
    + lib.optionalString (cudaOlder "10.1") ''
      cd $(basename $src)
      export PERL5LIB=.
      perl ./install-linux.pl --prefix="$out"
      cd ..
      for patch in $runPatches; do
        cd $(basename $patch)
        perl ./install_patch.pl --silent --accept-eula --installdir="$out"
        cd ..
      done
    ''
    + lib.optionalString (cudaAtLeast "10.1" && cudaOlder "11") ''
      cd pkg/builds/cuda-toolkit
      mv * $out/
      rm -f $out/nsight-systems-*/host-linux-x64/libstdc++.so*
    ''
    + lib.optionalString (cudaAtLeast "11") ''
      mkdir -p $out/bin $out/lib64 $out/include $doc
      for dir in pkg/builds/* pkg/builds/cuda_nvcc/nvvm pkg/builds/cuda_cupti/extras/CUPTI; do
        if [ -d $dir/bin ]; then
          mv $dir/bin/* $out/bin
        fi
        if [ -d $dir/doc ]; then
          (cd $dir/doc && find . -type d -exec mkdir -p $doc/\{} \;)
          (cd $dir/doc && find . \( -type f -o -type l \) -exec mv \{} $doc/\{} \;)
        fi
        if [ -L $dir/include ] || [ -d $dir/include ]; then
          (cd $dir/include && find . -type d -exec mkdir -p $out/include/\{} \;)
          (cd $dir/include && find . \( -type f -o -type l \) -exec mv \{} $out/include/\{} \;)
        fi
        if [ -L $dir/lib64 ] || [ -d $dir/lib64 ]; then
          (cd $dir/lib64 && find . -type d -exec mkdir -p $out/lib64/\{} \;)
          (cd $dir/lib64 && find . \( -type f -o -type l \) -exec mv \{} $out/lib64/\{} \;)
        fi
      done
      mv pkg/builds/cuda_nvcc/nvvm $out/nvvm

      mv pkg/builds/cuda_sanitizer_api $out/cuda_sanitizer_api
      ln -s $out/cuda_sanitizer_api/compute-sanitizer/compute-sanitizer $out/bin/compute-sanitizer

      mv pkg/builds/nsight_systems/target-linux-x64 $out/target-linux-x64
      mv pkg/builds/nsight_systems/host-linux-x64 $out/host-linux-x64
      rm $out/host-linux-x64/libstdc++.so*
    ''
    # error: auto-patchelf could not satisfy dependency libtiff.so.5 wanted by /nix/store/.......-cudatoolkit-12.0.1/host-linux-x64/Plugins/imageformats/libqtiff.so
    # we only ship libtiff.so.6, so let's use qt plugins built by Nix.
    # TODO: don't copy, come up with a symlink-based "merge"
    + lib.optionalString (cudaAtLeast "11.8" && cudaOlder "12") ''
      rsync ${lib.getLib qt6Packages.qtimageformats}/lib/qt-6/plugins/ $out/host-linux-x64/Plugins/ -aP
    ''
    # Use Qt plugins built by Nix.
    + lib.optionalString (cudaAtLeast "12") ''
      for qtlib in $out/host-linux-x64/Plugins/*/libq*.so; do
        qtdir=$(basename $(dirname $qtlib))
        filename=$(basename $qtlib)
        for qtpkgdir in ${
          lib.concatMapStringsSep " " (x: qt6Packages.${x}) [
            "qtbase"
            "qtimageformats"
            "qtsvg"
            "qtwayland"
          ]
        }; do
          if [ -e $qtpkgdir/lib/qt-6/plugins/$qtdir/$filename ]; then
            ln -snf $qtpkgdir/lib/qt-6/plugins/$qtdir/$filename $qtlib
          fi
        done
      done
    ''
    # FIXME: why?
    + ''
      rm -f $out/tools/CUDA_Occupancy_Calculator.xls
    ''
    + lib.optionalString (cudaOlder "10.1") ''
      # let's remove the 32-bit libraries, they confuse the lib64->lib mover
      rm -rf $out/lib
    ''
    + lib.optionalString (cudaAtLeast "12.0") ''
      rm $out/host-linux-x64/libQt6*
    ''
    # Remove some cruft.
    + lib.optionalString (cudaAtLeast "7.0" && cudaOlder "10.1") ''
      rm $out/bin/uninstall*
    ''
    # Fixup path to samples (needed for cuda 6.5 or else nsight will not find them)
    + ''
      if [ -d "$out"/cuda-samples ]; then
          mv "$out"/cuda-samples "$out"/samples
      fi
    ''
    # Change the #error on GCC > 4.9 to a #warning.
    + ''
      sed -i $out/include/host_config.h -e 's/#error\(.*unsupported GNU version\)/#warning\1/'
    ''
    # Fix builds with newer glibc version
    + ''
      sed -i "1 i#define _BITS_FLOATN_H" "$out/include/host_defines.h"
    ''
    # Point NVCC at a compatible compiler
    # CUDA_TOOLKIT_ROOT_DIR is legacy,
    # Cf. https://cmake.org/cmake/help/latest/module/FindCUDA.html#input-variables
    + ''
      mkdir -p $out/nix-support
      cat <<EOF >> $out/nix-support/setup-hook
      cmakeFlags+=' -DCUDA_TOOLKIT_ROOT_DIR=$out'
      EOF
    ''
    # Move some libraries to the lib output so that programs that
    # depend on them don't pull in this entire monstrosity.
    + ''
      mkdir -p $lib/lib
      mv -v $out/lib64/libcudart* $lib/lib/
    ''
    # Remove OpenCL libraries as they are provided by ocl-icd and driver.
    + ''
      rm -f $out/lib64/libOpenCL*
    ''
    + lib.optionalString (cudaAtLeast "10.1" && cudaOlder "11") ''
      mv $out/lib64 $out/lib
      mv $out/extras/CUPTI/lib64/libcupti* $out/lib
    ''
    # nvprof do not find any program to profile if LD_LIBRARY_PATH is not set
    + ''
      wrapProgram $out/bin/nvprof \
        --prefix LD_LIBRARY_PATH : $out/lib
    ''
    # 11.8 includes a broken symlink, include/include, pointing to targets/x86_64-linux/include
    + lib.optionalString (cudaMajorMinorVersion == "11.8") ''
      rm $out/include/include
    ''
    + ''
      runHook postInstall
    '';

  postInstall =
    ''
      for b in nvvp ${lib.optionalString (cudaOlder "11") "nsight"}; do
        wrapProgram "$out/bin/$b" \
          --set GDK_PIXBUF_MODULE_FILE "$GDK_PIXBUF_MODULE_FILE"
      done
    ''
    # Check we don't have any lurking vendored qt libraries that weren't
    # replaced during installPhase
    + lib.optionalString (cudaAtLeast "12") ''
      qtlibfiles=$(find $out -name "libq*.so" -type f)
      if [ ! -z "$qtlibfiles" ]; then
        echo "Found unexpected vendored Qt library files in $out" >&2
        echo $qtlibfiles >&2
        echo "These should be replaced with symlinks in installPhase" >&2
        exit 1
      fi
    ''
    # Add any missing fixups required by the CUDA GDB redist, which should be transferrable.
    + lib.optionalString (
      cuda_gdb != null
    ) cuda_gdb.passthru.fixups.cudatoolkit-legacy-runfile.postInstall;

  # cuda-gdb doesn't run correctly when not using sandboxing, so
  # temporarily disabling the install check.  This should be set to true
  # when we figure out how to get `cuda-gdb --version` to run correctly
  # when not using sandboxing.
  doInstallCheck = false;
  postInstallCheck =
    # Smoke test binaries
    ''
      pushd $out/bin
      for f in *; do
        case $f in
          crt)                           continue;;
          nvcc.profile)                  continue;;
          nsight_ee_plugins_manage.sh)   continue;;
          uninstall_cuda_toolkit_6.5.pl) continue;;
          computeprof|nvvp|nsight)       continue;; # GUIs don't feature "--version"
          *)                             echo "Executing '$f --version':"; ./$f --version;;
        esac
      done
      popd
    '';
  passthru = {
    inherit (backendStdenv) cc;
    majorMinorVersion = cudaMajorMinorVersion;
    majorVersion = cudaMajorVersion;
  };

  meta = with lib; {
    description = "Deprecated runfile-based CUDAToolkit installation (a compiler for NVIDIA GPUs, math libraries, and tools)";
    homepage = "https://developer.nvidia.com/cuda-toolkit";
    platforms = [ "x86_64-linux" ];
    license = licenses.nvidiaCuda;
    maintainers = teams.cuda.members;
  };
})