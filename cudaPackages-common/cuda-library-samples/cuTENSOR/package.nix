{
  cuda-library-samples,
  lib,
  libcublas,
  libcutensor,
}:
let
  inherit (lib.attrsets) getLib getOutput;
  inherit (lib.strings) cmakeOptionType;
  cmakePath = cmakeOptionType "PATH";
in
cuda-library-samples.sample-builder (
  finalAttrs: prevAttrs: {
    sampleName = "cuTENSOR";
    sourceRoot = "source/${finalAttrs.sampleName}";
    installExecutablesMatchingPattern = "cuTENSOR_example_*";

    postPatch =
      prevAttrs.postPatch or ""
      # Their CMakeLists.txt is old and broken; use ours.
      + ''
        cp -f ${./CMakeLists.txt} CMakeLists.txt
      '';

    cmakeFlags = prevAttrs.cmakeFlags or [ ] ++ [
      (cmakePath "CUTENSOR_INCLUDE_DIR" (getOutput "include" libcutensor).outPath)
      (cmakePath "CUTENSOR_LIB_DIR" (getLib libcutensor).outPath)
    ];

    buildInputs = prevAttrs.buildInputs or [ ] ++ [
      libcublas
      libcutensor
    ];
  }
)
