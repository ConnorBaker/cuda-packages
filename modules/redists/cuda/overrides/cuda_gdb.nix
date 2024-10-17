{
  cudaAtLeast,
  cudaMajorMinorVersion,
  expat,
  gmp,
  lib,
  libxcrypt-legacy,
  ncurses,
  python3,
  stdenv,
}:
let
  inherit (lib.lists) optionals;
  inherit (lib.strings) optionalString versionAtLeast versionOlder;
  inherit (lib.versions) majorMinor;
  python3MajorMinorVersion = majorMinor python3.version;
in
prevAttrs: {
  allowFHSReferences = true;

  brokenConditions = prevAttrs.brokenConditions // {
    "Unsupported Python 3 version" =
      (cudaAtLeast "12.5")
      && (versionOlder python3MajorMinorVersion "3.8" || versionAtLeast python3MajorMinorVersion "3.13");
  };

  buildInputs =
    prevAttrs.buildInputs or [ ]
    # x86_64 only needs gmp from 12.0 and on
    ++ optionals (cudaAtLeast "12.0") [ gmp ]
    # aarch64, sbsa needs expat
    ++ optionals stdenv.hostPlatform.isAarch64 [ expat ]
    # From 12.5, cuda-gdb comes with Python TUI wrappers
    ++ optionals (cudaAtLeast "12.5") [
      libxcrypt-legacy
      ncurses
      python3
    ];

  postInstall =
    prevAttrs.postInstall or ""
    # Remove binaries requiring Python3 versions we do not have
    + optionalString (cudaAtLeast "12.5") ''
      pushd "''${!outputBin}/bin"
      mv "cuda-gdb-python${python3MajorMinorVersion}-tui" ../
      rm -f cuda-gdb-python*-tui
      mv "../cuda-gdb-python${python3MajorMinorVersion}-tui" . 
      popd
    '';
}
