{ lib }:
let
  inherit (lib.cuda.types) attrs cudaRealArch;
  inherit (lib.cuda.utils) mkOptionsModule;
  inherit (lib.types)
    enum
    nonEmptyListOf
    nonEmptyStr
    nullOr
    oneOf
    strMatching
    ;
in
mkOptionsModule {
  cudaArchitectures = {
    description = ''
      Real CUDA architectures supported by the package

      A value of `null` indicates that the package is not specific to any architecture.
    '';
    type = nullOr (oneOf [
      (nonEmptyListOf cudaRealArch) # Flat lib directory
      (attrs nonEmptyStr cudaRealArch) # CUDA versioned lib directory
    ]);
    default = null;
  };
  cudaVersionsInLib = {
    description = "Subdirectories of the `lib` directory which are named after CUDA versions";
    type = nullOr (nonEmptyListOf (strMatching "^[[:digit:]]+(\.[[:digit:]]+)?$"));
    default = null;
  };
  outputs = {
    description = ''
      The outputs provided by a package.

      A `bin` output requires that we have a non-empty `bin` directory containing at least one file with the
      executable bit set.

      A `dev` output requires that we have at least one of the following non-empty directories:

      - `lib/pkgconfig`
      - `share/pkgconfig`
      - `lib/cmake`
      - `share/aclocal`

      NOTE: Absent from this list is `include`, which is handled by the `include` output. This is because the `dev`
      output in Nixpkgs is used for development files and is selected as the default output to install if present.
      Since we want to be able to access only the header files, they are present in a separate output.

      A `doc` output requires that we have at least one of the following non-empty directories:

      - `share/info`
      - `share/doc`
      - `share/gtk-doc`
      - `share/devhelp`
      - `share/man`

      An `include` output requires that we have a non-empty `include` directory.

      A `lib` output requires that we have a non-empty lib directory containing at least one shared library.

      A `python` output requires that we have a non-empty `python` directory.

      A `sample` output requires that we have a non-empty `samples` directory.

      A `static` output requires that we have a non-empty lib directory containing at least one static library.

      A `stubs` output requires that we have a non-empty `lib/stubs` or `stubs` directory containing at least one
      shared or static library.
    '';
    type = nonEmptyListOf (enum [
      "out" # Always present
      "bin"
      "dev"
      "doc"
      "include"
      "lib"
      "python"
      "sample"
      "static"
      "stubs"
    ]);
  };
}
