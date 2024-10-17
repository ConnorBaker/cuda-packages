{
  cuda-library-samples,
  libcublas,
  libcusolver,
  libcusparse,
}:
cuda-library-samples.sample-builder (
  finalAttrs: prevAttrs: {
    sampleName = "cuSOLVER";
    sourceRoot = "source/${finalAttrs.sampleName}";
    installExecutablesMatchingPattern = "cusolver_*_example";

    postPatch =
      prevAttrs.postPatch or ""
      # Create a stub CMakeLists.txt file in the root of the sample directory.
      # We add a custom target for the examples, to which the function defined in cmake/cusolver_example.cmake will add
      # our samples.
      + ''
        cat <<EOF > CMakeLists.txt
        cmake_minimum_required(VERSION 3.18.0 FATAL_ERROR)
        project(cusolver_examples LANGUAGES C CXX CUDA)
        add_custom_target(cusolver_examples)
        EOF
      ''
      # Patch cmake/cusolver_example.cmake so it doesn't keep trying to add the same target since we do it once in our
      # own CMakeLists.txt.
      + ''
        substituteInPlace "cmake/cusolver_example.cmake" \
          --replace-fail \
            "add_custom_target(cusolver_examples)" \
            ""
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
                "project(cusolver_examples " \
                "project(cusolver_$path_example " \
              --replace-fail \
                'include_directories("''${CMAKE_SOURCE_DIR}/../utils")' \
                'include_directories("''${CMAKE_SOURCE_DIR}/utils")'
          else
            continue
          fi
        done
      '';

    buildInputs = prevAttrs.buildInputs or [ ] ++ [
      libcublas
      libcusolver
      libcusparse
    ];
  }
)
