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
  pname = "clog";
  inherit (cpuinfo) version;
  src = "${cpuinfo.src}/deps/clog";

  # gtest requires at least C++14
  postPatch = ''
    substituteInPlace CMakeLists.txt \
      --replace-fail \
        "CXX_STANDARD 11" \
        "CXX_STANDARD 14"
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
