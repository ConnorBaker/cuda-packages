{
  cuda-library-samples,
  lib,
  libnpp_plus,
}:
let
  inherit (lib.attrsets) getOutput;
in
cuda-library-samples.sample-builder (prevAttrs: {
  sampleName = "NPPPlus";
  sourceRoot = "source/NPP+";
  installExecutablesMatchingPattern = "npp_plus_example_*";

  postPatch =
    prevAttrs.postPatch or ""
    # Create a stub CMakeLists.txt file in the root of the sample directory.
    # We add a custom target for the examples.
    + ''
      cat <<EOF > CMakeLists.txt
      cmake_minimum_required(VERSION 3.18.0 FATAL_ERROR)
      project(npp_plus_examples LANGUAGES C CXX CUDA)
      EOF
    ''
    # Add all the subdirectories containing a CMakeLists.txt to our CMakeLists.txt, correcting the path to their
    # header dependencies since the CMAKE_SOURCE_DIR is now one level up (the directory containing our
    # CMakeLists.txt).
    + ''
      for path in *
      do
        if [[ -e "$path/CMakeLists.txt" ]]
        then
          echo "add_subdirectory($path)" >> CMakeLists.txt
          substituteInPlace "$path/CMakeLists.txt" \
            --replace-fail \
              "SET(PROJECT_NAME " \
              "SET(PROJECT_NAME npp_plus_example_" \
            --replace-fail \
              "/usr/include/nppPlus" \
              "${getOutput "include" libnpp_plus}/include/nppPlus"
        else
          continue
        fi
      done
    '';

  buildInputs = prevAttrs.buildInputs or [ ] ++ [
    libnpp_plus
  ];
})
