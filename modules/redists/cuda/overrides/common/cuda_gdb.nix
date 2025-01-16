{
  cudaAtLeast,
  expat,
  gmp,
  lib,
  libxcrypt-legacy,
  ncurses,
  python3,
  stdenv,
}:
let
  inherit (lib.attrsets) recursiveUpdate;
  inherit (lib.lists) optionals;
  inherit (lib.strings) optionalString versionAtLeast versionOlder;
  inherit (lib.versions) majorMinor;
  python3MajorMinorVersion = majorMinor python3.version;
in
prevAttrs: {
  allowFHSReferences = true;

  buildInputs =
    prevAttrs.buildInputs or [ ]
    ++ [ gmp ]
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
      nixLog "removing cuda-gdb-python*-tui binaries for Python 3 versions other than ${python3MajorMinorVersion}"
      for pygdb in cuda-gdb-python*-tui; do
        if [[ "$pygdb" == "cuda-gdb-python${python3MajorMinorVersion}-tui" ]]; then
          continue
        fi
        nixLog "removing $pygdb"
        rm -rf "$pygdb"
      done
      popd
    '';

  passthru = recursiveUpdate (prevAttrs.passthru or { }) {
    brokenConditions = {
      "Unsupported Python 3 version" =
        (cudaAtLeast "12.5")
        && (versionOlder python3MajorMinorVersion "3.8" || versionAtLeast python3MajorMinorVersion "3.13");
    };
  };
}
