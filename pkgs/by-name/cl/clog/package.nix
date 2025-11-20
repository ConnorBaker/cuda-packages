{
  cmake,
  cpuinfo,
  gtest,
  lib,
  ninja,
  stdenv,
}:
let
  inherit (lib) licenses maintainers;
  inherit (lib.strings) cmakeBool;
in
stdenv.mkDerivation (finalAttrs: {
  __structuredAttrs = true;
  strictDeps = true;

  pname = "clog";
  inherit (cpuinfo) src version;
  sourceRoot = "${cpuinfo.src.name}/deps/clog";

  # NOTE: Can be removed after cpuinfo includes https://github.com/pytorch/cpuinfo/pull/318.
  postPatch = ''
    nixLog "patching $PWD/CMakeLists.txt to use a newer C++ standard for gtest"
    substituteInPlace "$PWD/CMakeLists.txt" \
      --replace-fail \
        "CXX_STANDARD 11" \
        "CXX_STANDARD 17"
  '';

  nativeBuildInputs = [
    cmake
    ninja
  ];

  checkInputs = [ gtest ];

  cmakeFlags = [
    (cmakeBool "USE_SYSTEM_GOOGLETEST" true)
    (cmakeBool "USE_SYSTEM_LIBS" true)
    (cmakeBool "CLOG_BUILD_TESTS" finalAttrs.doCheck)
  ];

  doCheck = true;

  meta = {
    description = "C-style library for logging errors, warnings, information notes, and debug information";
    homepage = "https://github.com/pytorch/cpuinfo/tree/main/deps/clog";
    license = licenses.bsd2;
    maintainers = with maintainers; [ connorbaker ];
  };
})
