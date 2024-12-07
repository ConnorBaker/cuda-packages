{
  backendStdenv,
  blas,
  boost,
  buildPackages,
  callPackage,
  cmake,
  cuda_cccl,
  cuda_cudart,
  cuda_nvcc,
  cudnn,
  doxygen,
  eigen,
  elfutils,
  enableBlas ? true,
  enableContrib ? true,
  enableCudnn ? false, # NOTE: CUDNN has a large impact on closure size so we disable it by default
  enableDC1394 ? false,
  enableDocs ? false,
  enableEigen ? true,
  enableEXR ? true,
  enableFfmpeg ? true,
  enableGPhoto2 ? false,
  enableGStreamer ? true,
  enableGtk2 ? false,
  enableGtk3 ? false,
  enableIpp ? false,
  enableJPEG ? true,
  enableJPEG2000 ? true,
  enableLto ? false, # Broken currently
  enableNvidiaVideoCodecSdk ? true, # NOTE: requires manual download
  enableOvis ? false,
  enablePNG ? true,
  enablePython ? true,
  enableTbb ? false,
  enableTesseract ? false,
  enableTIFF ? true,
  enableVA ? true,
  enableVtk ? false,
  enableWebP ? true,
  fetchFromGitHub,
  fetchurl,
  ffmpeg,
  flags,
  gflags,
  glib,
  graphviz-nox,
  gst_all_1,
  gtk2,
  gtk3,
  hdf5,
  ilmbase,
  leptonica,
  lib,
  libcublas,
  libcufft,
  libdc1394,
  libgphoto2,
  libjpeg,
  libnpp,
  libpng,
  libtiff,
  libunwind,
  libva,
  libwebp,
  nvidia-optical-flow-sdk,
  nvidia-video-codec-sdk,
  ocl-icd,
  ogre,
  opencv4,
  openexr,
  openjpeg,
  orc,
  pcre2,
  pkg-config,
  protobuf_25,
  python3Packages,
  qimgv,
  tbb,
  tesseract,
  unzip,
  vtk,
  zlib,
  zstd,

  runAccuracyTests ? true,
  runPerformanceTests ? false,
  # Modules to enable via BUILD_LIST to build a customized opencv.
  # An empty lists means this setting is ommited which matches upstreams default.
  enabledModules ? [ ],
}:

let
  inherit (backendStdenv) buildPlatform hostPlatform;
  inherit (flags) cmakeCudaArchitecturesString cudaCapabilities;
  inherit (lib.attrsets) mapAttrsToList optionalAttrs;
  inherit (lib.lists) last optionals;
  inherit (lib.meta) getExe;
  inherit (lib.strings)
    cmakeBool
    cmakeFeature
    cmakeOptionType
    concatStrings
    concatStringsSep
    optionalString
    ;
  inherit (lib.trivial) flip;
  inherit (python3Packages)
    numpy
    pip
    python
    setuptools
    wheel
    ;

  # TODO:
  # https://developer.nvidia.com/nvidia-video-codec-sdk/download
  # cuda12.6-opencv> CMake Warning at opencv_contrib/cudacodec/CMakeLists.txt:26 (message):
  # cuda12.6-opencv>   cudacodec::VideoReader requires Nvidia Video Codec SDK.  Please resolve
  # cuda12.6-opencv>   dependency or disable WITH_NVCUVID=OFF
  # cuda12.6-opencv>
  # cuda12.6-opencv> CMake Warning at opencv_contrib/cudacodec/CMakeLists.txt:30 (message):
  # cuda12.6-opencv>   cudacodec::VideoWriter requires Nvidia Video Codec SDK.  Please resolve
  # cuda12.6-opencv>   dependency or disable WITH_NVCUVENC=OFF

  contribSrc = callPackage ./opencv_contrib.nix { };

  testDataSrc = callPackage ./opencv_extra.nix { };

  # Contrib must be built in order to enable Tesseract support:
  buildContrib = enableContrib || enableTesseract || enableOvis;

  # See opencv/3rdparty/ippicv/ippicv.cmake
  ippicv = {
    src =
      fetchFromGitHub {
        owner = "opencv";
        repo = "opencv_3rdparty";
        rev = "0cc4aa06bf2bef4b05d237c69a5a96b9cd0cb85a";
        hash = "sha256-/kHivOgCkY9YdcRRaVgytXal3ChE9xFfGAB0CfFO5ec=";
      }
      + "/ippicv";
    files =
      let
        name = platform: "ippicv_2021.10.0_${platform}_20230919_general.tgz";
      in
      if hostPlatform.system == "x86_64-linux" then
        { ${name "lnx_intel64"} = "606a19b207ebedfe42d59fd916cc4850"; }
      else
        throw "ICV is not available for this platform (or not yet supported by this package)";
    dst = ".cache/ippicv";
  };

  # See opencv_contrib/modules/xfeatures2d/cmake/download_vgg.cmake
  vgg = {
    src = fetchFromGitHub {
      owner = "opencv";
      repo = "opencv_3rdparty";
      rev = "fccf7cd6a4b12079f73bbfb21745f9babcd4eb1d";
      hash = "sha256-fjdGM+CxV1QX7zmF2AiR9NDknrP2PjyaxtjT21BVLmU=";
    };
    files = {
      "vgg_generated_48.i" = "e8d0dcd54d1bcfdc29203d011a797179";
      "vgg_generated_64.i" = "7126a5d9a8884ebca5aea5d63d677225";
      "vgg_generated_80.i" = "7cd47228edec52b6d82f46511af325c5";
      "vgg_generated_120.i" = "151805e03568c9f490a5e3a872777b75";
    };
    dst = ".cache/xfeatures2d/vgg";
  };

  # See opencv_contrib/modules/xfeatures2d/cmake/download_boostdesc.cmake
  boostdesc = {
    src = fetchFromGitHub {
      owner = "opencv";
      repo = "opencv_3rdparty";
      rev = "34e4206aef44d50e6bbcd0ab06354b52e7466d26";
      sha256 = "13yig1xhvgghvxspxmdidss5lqiikpjr0ddm83jsi0k85j92sn62";
    };
    files = {
      "boostdesc_bgm.i" = "0ea90e7a8f3f7876d450e4149c97c74f";
      "boostdesc_bgm_bi.i" = "232c966b13651bd0e46a1497b0852191";
      "boostdesc_bgm_hd.i" = "324426a24fa56ad9c5b8e3e0b3e5303e";
      "boostdesc_binboost_064.i" = "202e1b3e9fec871b04da31f7f016679f";
      "boostdesc_binboost_128.i" = "98ea99d399965c03d555cef3ea502a0b";
      "boostdesc_binboost_256.i" = "e6dcfa9f647779eb1ce446a8d759b6ea";
      "boostdesc_lbgm.i" = "0ae0675534aa318d9668f2a179c2a052";
    };
    dst = ".cache/xfeatures2d/boostdesc";
  };

  # See opencv_contrib/modules/face/CMakeLists.txt
  face = {
    src = fetchFromGitHub {
      owner = "opencv";
      repo = "opencv_3rdparty";
      rev = "8afa57abc8229d611c4937165d20e2a2d9fc5a12";
      hash = "sha256-m9yF4kfmpRJybohdRwUTmboeU+SbZQ6F6gm32PDWNBg=";
    };
    files = {
      "face_landmark_model.dat" = "7505c44ca4eb54b4ab1e4777cb96ac05";
    };
    dst = ".cache/data";
  };

  # See opencv/modules/gapi/cmake/DownloadADE.cmake
  ade = rec {
    src = fetchurl {
      url = "https://github.com/opencv/ade/archive/${name}";
      hash = "sha256-WG/GudVpkO10kOJhoKXFMj672kggvyRYCIpezal3wcE=";
    };
    name = "v0.1.2d.zip";
    md5 = "dbb095a8bf3008e91edbbf45d8d34885";
    dst = ".cache/ade";
  };

  # See opencv_contrib/modules/wechat_qrcode/CMakeLists.txt
  wechat_qrcode = {
    src = fetchFromGitHub {
      owner = "opencv";
      repo = "opencv_3rdparty";
      rev = "a8b69ccc738421293254aec5ddb38bd523503252";
      hash = "sha256-/n6zHwf0Rdc4v9o4rmETzow/HTv+81DnHP+nL56XiTY=";
    };
    files = {
      "detect.caffemodel" = "238e2b2d6f3c18d6c3a30de0c31e23cf";
      "detect.prototxt" = "6fb4976b32695f9f5c6305c19f12537d";
      "sr.caffemodel" = "cbfcd60361a73beb8c583eea7e8e6664";
      "sr.prototxt" = "69db99927a70df953b471daaba03fbef";
    };
    dst = ".cache/wechat_qrcode";
  };

  # See opencv/cmake/OpenCVDownload.cmake
  installExtraFiles =
    {
      dst,
      files,
      src,
      ...
    }:
    ''
      mkdir -p "${dst}"
    ''
    + concatStrings (
      flip mapAttrsToList files (
        name: md5: ''
          ln -s "${src}/${name}" "${dst}/${md5}-${name}"
        ''
      )
    );

  installExtraFile =
    {
      dst,
      md5,
      name,
      src,
      ...
    }:
    ''
      mkdir -p "${dst}"
      ln -s "${src}" "${dst}/${md5}-${name}"
    '';

  withOpenblas = enableBlas && blas.provider.pname == "openblas";
  #multithreaded openblas conflicts with opencv multithreading, which manifest itself in hung tests
  #https://github.com/OpenMathLib/OpenBLAS/wiki/Faq/4bded95e8dc8aadc70ce65267d1093ca7bdefc4c#multi-threaded
  openblas_ = blas.provider.override { singleThreaded = true; };
in
backendStdenv.mkDerivation (finalAttrs: {
  pname = "opencv";

  version = "4.10.0";

  src = fetchFromGitHub {
    owner = "opencv";
    repo = "opencv";
    rev = "refs/tags/${finalAttrs.version}";
    hash = "sha256-s+KvBrV/BxrxEvPhHzWCVFQdUQwhUdRJyb0wcGDFpeo=";
  };

  outputs =
    [
      "out"
      "cxxdev"
    ]
    ++ optionals (runAccuracyTests || runPerformanceTests) [
      "package_tests"
    ];

  cudaPropagateToOutput = "cxxdev";

  nativeBuildInputs =
    [
      cmake
      cuda_nvcc
      pkg-config
      unzip
    ]
    ++ optionals enablePython [
      pip
      wheel
      setuptools
    ];

  # Ensures that we use the system OpenEXR rather than the vendored copy of the source included with OpenCV.
  patches = [
    ./cmake-don-t-use-OpenCVFindOpenEXR.patch
    ./cuda_opt_flow.patch
  ];

  prePatch =
    optionalString buildContrib ''
      cp --no-preserve=mode -r "${contribSrc}/modules" "$NIX_BUILD_TOP/$sourceRoot/opencv_contrib"
    ''
    # Patch to use the system nvidia-video-codec-sdk and not look at the wrong CMake variable for the path.
    # https://github.com/opencv/opencv/blob/96dab6ba7181d2de71e014e750354b7111d10dac/cmake/OpenCVDetectCUDAUtils.cmake
    + ''
      substituteInPlace cmake/OpenCVDetectCUDALanguage.cmake \
        --replace-fail \
          'ocv_check_for_nvidia_video_codec_sdk("''${CUDAToolkit_LIBRARY_ROOT}")' \
          'ocv_check_for_nvidia_video_codec_sdk("''${CUDAToolkit_ROOT}")'
    '';

  # This prevents cmake from using libraries in impure paths (which
  # causes build failure on non NixOS)
  postPatch = ''
    sed -i '/Add these standard paths to the search paths for FIND_LIBRARY/,/^\s*$/{d}' CMakeLists.txt
  '';

  preConfigure =
    installExtraFile ade
    + optionalString enableIpp (installExtraFiles ippicv)
    + optionalString buildContrib ''
      cmakeFlagsArray+=("-DOPENCV_EXTRA_MODULES_PATH=$NIX_BUILD_TOP/$sourceRoot/opencv_contrib")

      ${installExtraFiles vgg}
      ${installExtraFiles boostdesc}
      ${installExtraFiles face}
      ${installExtraFiles wechat_qrcode}
    '';

  postConfigure = ''
    if [[ ! -e modules/core/version_string.inc ]]; then
      nixErrorLog "modules/core/version_string.inc does not exist"
      exit 1
    fi
    echo '"(build info elided)"' > modules/core/version_string.inc
  '';

  buildInputs =
    [
      boost
      cuda_cccl # <thrust/*>
      cuda_cudart
      gflags
      glib
      libcublas # cublas_v2.h
      libcufft # cufft.h
      libnpp # npp.h
      nvidia-optical-flow-sdk
      nvidia-video-codec-sdk
      pcre2
      protobuf_25
      zlib
    ]
    ++ optionals enableCudnn [
      cudnn # cudnn.h
    ]
    ++ optionals enablePython [
      python
    ]
    ++ optionals (buildPlatform == hostPlatform) [
      hdf5
    ]
    ++ optionals enableGtk2 [
      gtk2
    ]
    ++ optionals enableGtk3 [
      gtk3
    ]
    ++ optionals enableVtk [
      vtk
    ]
    ++ optionals enableJPEG [
      libjpeg
    ]
    ++ optionals enablePNG [
      libpng
    ]
    ++ optionals enableTIFF [
      libtiff
    ]
    ++ optionals enableWebP [
      libwebp
    ]
    ++ optionals enableEXR [
      openexr
      ilmbase
    ]
    ++ optionals enableJPEG2000 [
      openjpeg
    ]
    ++ optionals enableFfmpeg [
      ffmpeg
    ]
    ++ optionals (enableGStreamer && hostPlatform.isLinux) [
      elfutils
      gst_all_1.gst-plugins-base
      gst_all_1.gst-plugins-good
      gst_all_1.gstreamer
      libunwind
      orc
      zstd
    ]
    ++ optionals enableOvis [
      ogre
    ]
    ++ optionals enableGPhoto2 [
      libgphoto2
    ]
    ++ optionals enableDC1394 [
      libdc1394
    ]
    ++ optionals enableEigen [
      eigen
    ]
    ++ optionals enableVA [
      libva
    ]
    ++ optionals enableBlas [
      blas.provider
    ]
    ++ optionals enableTesseract [
      # There is seemingly no compile-time flag for Tesseract.  It's
      # simply enabled automatically if contrib is built, and it detects
      # tesseract & leptonica.
      tesseract
      leptonica
    ]
    ++ optionals enableTbb [
      tbb
    ]
    ++ optionals enableDocs [
      doxygen
      graphviz-nox
    ];

  propagatedBuildInputs = optionals enablePython [ numpy ];

  env = {
    NIX_CFLAGS_COMPILE = optionalString enableEXR "-I${ilmbase.dev}/include/OpenEXR";
    # Configure can't find the library without this.
    OpenBLAS_HOME = optionalString withOpenblas openblas_.dev;
    OpenBLAS = optionalString withOpenblas openblas_;
  };

  cmakeFlags =
    [
      (cmakeBool "OPENCV_GENERATE_PKGCONFIG" true)
      (cmakeBool "WITH_OPENMP" true)
      (cmakeBool "BUILD_PROTOBUF" false)
      (cmakeOptionType "path" "Protobuf_PROTOC_EXECUTABLE" (getExe buildPackages.protobuf_25))
      (cmakeBool "PROTOBUF_UPDATE_FILES" true)
      (cmakeBool "OPENCV_ENABLE_NONFREE" true)
      (cmakeBool "BUILD_TESTS" runAccuracyTests)
      (cmakeBool "BUILD_PERF_TESTS" runPerformanceTests)
      (cmakeBool "CMAKE_SKIP_BUILD_RPATH" true)
      (cmakeBool "BUILD_DOCS" enableDocs)
      # "OpenCV disables pkg-config to avoid using of host libraries. Consider using PKG_CONFIG_LIBDIR to specify target SYSROOT"
      # but we have proper separation of build and host libs :), fixes cross
      (cmakeBool "OPENCV_ENABLE_PKG_CONFIG" true)
      (cmakeBool "WITH_IPP" enableIpp)
      (cmakeBool "WITH_TIFF" enableTIFF)
      (cmakeBool "WITH_WEBP" enableWebP)
      (cmakeBool "WITH_JPEG" enableJPEG)
      (cmakeBool "WITH_PNG" enablePNG)
      (cmakeBool "WITH_OPENEXR" enableEXR)
      (cmakeBool "WITH_OPENJPEG" enableJPEG2000)
      (cmakeBool "WITH_JASPER" false) # OpenCV falls back to a vendored copy of Jasper when OpenJPEG is disabled
      (cmakeBool "WITH_TBB" enableTbb)

      (cmakeOptionType "path" "OPENCL_LIBRARY" "${ocl-icd}/lib/libOpenCL.so")

      # CUDA options
      (cmakeBool "ENABLE_CUDA_FIRST_CLASS_LANGUAGE" true)
      (cmakeBool "WITH_CUDA" true)
      (cmakeBool "WITH_CUBLAS" true)
      (cmakeBool "WITH_CUDNN" enableCudnn)
      (cmakeBool "WITH_CUFFT" true)
      (cmakeBool "WITH_NVCUVID" enableNvidiaVideoCodecSdk)
      (cmakeBool "WITH_NVCUVENC" enableNvidiaVideoCodecSdk)

      # LTO options
      (cmakeBool "ENABLE_LTO" enableLto)
      # Only clang supports thin LTO
      (cmakeBool "ENABLE_THIN_LTO" (enableLto && backendStdenv.cc.isClang))

      (cmakeBool "CUDA_FAST_MATH" true)
      (cmakeFeature "CUDA_NVCC_FLAGS" "--expt-relaxed-constexpr")

      # OpenCV respects at least three variables:
      # -DCUDA_GENERATION takes a single arch name, e.g. Volta
      # -DCUDA_ARCH_BIN takes a semi-colon separated list of real arches, e.g. "8.0;8.6"
      # -DCUDA_ARCH_PTX takes the virtual arch, e.g. "8.6"
      (cmakeFeature "CUDA_ARCH_BIN" cmakeCudaArchitecturesString)
      (cmakeFeature "CUDA_ARCH_PTX" (last cudaCapabilities))

      (cmakeOptionType "path" "NVIDIA_OPTICAL_FLOW_2_0_HEADERS_PATH" nvidia-optical-flow-sdk.outPath)
    ]
    ++ optionals enablePython [
      (cmakeOptionType "path" "OPENCV_PYTHON_INSTALL_PATH" python.sitePackages)
    ]
    ++ optionals (enabledModules != [ ]) [
      (cmakeFeature "BUILD_LIST" (concatStringsSep "," enabledModules))
    ];

  postBuild = optionalString enableDocs ''
    make doxygen
  '';

  preInstall =
    optionalString (runAccuracyTests || runPerformanceTests) ''
      mkdir "$package_tests"
      cp -R "$src/samples" "$package_tests/"
    ''
    + optionalString runAccuracyTests ''
      mv ./bin/*test* "$package_tests/"
    ''
    + optionalString runPerformanceTests ''
      mv ./bin/*perf* "$package_tests/"
    '';

  # By default $out/lib/pkgconfig/opencv4.pc looks something like this:
  #
  #   prefix=/nix/store/g0wnfyjjh4rikkvp22cpkh41naa43i4i-opencv-4.0.0
  #   exec_prefix=${prefix}
  #   libdir=${exec_prefix}//nix/store/g0wnfyjjh4rikkvp22cpkh41naa43i4i-opencv-4.0.0/lib
  #   includedir_old=${prefix}//nix/store/g0wnfyjjh4rikkvp22cpkh41naa43i4i-opencv-4.0.0/include/opencv4/opencv
  #   includedir_new=${prefix}//nix/store/g0wnfyjjh4rikkvp22cpkh41naa43i4i-opencv-4.0.0/include/opencv4
  #   ...
  #   Libs: -L${exec_prefix}//nix/store/g0wnfyjjh4rikkvp22cpkh41naa43i4i-opencv-4.0.0/lib ...
  # Note that ${exec_prefix} is set to $out but that $out is also appended to
  # ${exec_prefix}. This causes linker errors in downstream packages so we strip
  # of $out after the ${exec_prefix} and ${prefix} prefixes:
  postInstall =
    ''
      sed -i "s|{exec_prefix}/$out|{exec_prefix}|;s|{prefix}/$out|{prefix}|" \
        "$out/lib/pkgconfig/opencv4.pc"
      mkdir "$cxxdev"
    ''
    # remove the requirement that the exact same version of CUDA is used in packages
    # consuming OpenCV's CMakes files
    + ''
      substituteInPlace "$out/lib/cmake/opencv4/OpenCVConfig.cmake" \
        --replace-fail \
          'find_package(CUDAToolkit ''${OpenCV_CUDA_VERSION} EXACT REQUIRED)' \
          'find_package(CUDAToolkit REQUIRED)' \
        --replace-fail \
          'message(FATAL_ERROR "OpenCV library was compiled with CUDA' \
          'message("OpenCV library was compiled with CUDA'
    ''
    # install python distribution information, so other packages can `import opencv`
    + optionalString enablePython ''
      pushd "$NIX_BUILD_TOP/$sourceRoot/modules/python/package"
      python -m pip wheel --verbose --no-index --no-deps --no-clean --no-build-isolation --wheel-dir dist .

      pushd dist
      python -m pip install ./*.whl --no-index --no-warn-script-location --prefix="$out" --no-cache

      popd
      popd
    '';

  passthru = {
    tests = {
      inherit (gst_all_1) gst-plugins-bad;
      inherit qimgv;
      opencv4-tests = callPackage ./tests.nix {
        inherit
          enableGStreamer
          enableGtk2
          enableGtk3
          runAccuracyTests
          runPerformanceTests
          testDataSrc
          ;
        inherit opencv4;
      };
      no-libstdcxx-errors = callPackage ./libstdcxx-test.nix { attrName = "opencv4"; };
    } // optionalAttrs (!enablePython) { pythonEnabled = python3Packages.opencv4; };
  } // optionalAttrs enablePython { pythonPath = [ ]; };

  meta = {
    description = "Open Computer Vision Library with more than 500 algorithms";
    homepage = "https://opencv.org/";
    license = lib.licenses.unfree;
    maintainers = (with lib.maintainers; [ connorbaker ]) ++ lib.teams.cuda.members;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
  };
})
