{
  backendStdenv,
  fetchzip,
  lib,
}:
let
  inherit (lib.strings) concatStringsSep;
  baseURL = "https://developer.download.nvidia.com/compute/cublasdx/redist/cublasdx";
in
# NOTE(@connorbaker): The docs are a large portion of headers tarball. They're also duplicated in
# include/{cublasdx,cufftdx}/docs.
# TODO: They vendor a copy of cutlass in the zip under external...
# headers = fetchzip {
#   name = "nvidia-mathdx-24.08.0";
#   url = "${baseURL}/nvidia-mathdx-24.08.0.tar.gz";
#   hash = "sha256-nSzDzjSH8yfL0r67AbwJ47aBz59Ib4e/sgyNtI7zg4M=";
# };
backendStdenv.mkDerivation (finalAttrs: {
  pname = "libmathdx";
  version = "0.1.0";

  src =
    let
      name = concatStringsSep "-" [
        finalAttrs.pname
        "Linux"
        backendStdenv.hostPlatform.parsed.cpu.name
        finalAttrs.version
      ];
    in
    fetchzip {
      inherit name;
      url = "${baseURL}/${name}.tar.gz";
      hash = "sha256-7BoghYBo19NgmjYoGA1VkeWciSf8B5jOddKRi9/rlBg=";
    };

  # Everything else should be kept in the same output. While there are some shared libraries, I'm not familiar enough
  # with the project to know how they're used or if it's safe to split them out/change the directory structures.
  outputs = [
    "out"
    "static"
  ];

  # Update the sourceRoot
  preInstall = ''
    mkdir -p "$out"
    mv * "$out"
    mkdir -p "$static"
    moveToOutput "lib/libmathdx_static.a" "$static"
  '';

  doCheck = false;

  meta = {
    description = "A library used to integrate cuBLASDx and cuFFTDx into Warp";
    homepage = "https://developer.nvidia.com/cublasdx-downloads";
    license = {
      fullName = "LICENSE AGREEMENT FOR NVIDIA MATH LIBRARIES SOFTWARE DEVELOPMENT KITS";
      url = "https://developer.download.nvidia.com/compute/mathdx/License.txt";
      free = false;
    };
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = (with lib.maintainers; [ connorbaker ]) ++ lib.teams.cuda.members;
  };
})
