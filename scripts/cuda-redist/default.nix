{
  annotated-types,
  buildPythonPackage,
  cudaPackages,
  flit-core,
  lib,
  makeWrapper,
  nixVersions,
  patchelf,
  pydantic,
  pyright,
  pythonAtLeast,
  rich,
  ruff,
}:
let
  inherit (lib.fileset) toSource unions;
  inherit (lib.strings) makeBinPath;
  inherit (lib.trivial) importTOML;
  pyprojectAttrs = importTOML ./pyproject.toml;
  finalAttrs = {
    pname = pyprojectAttrs.project.name;
    inherit (pyprojectAttrs.project) version;
    pyproject = true;
    disabled = pythonAtLeast "3.12";
    src = toSource {
      root = ./.;
      fileset = unions [
        ./pyproject.toml
        ./cuda_redist
      ];
    };
    nativeBuildInputs = [ makeWrapper ];
    build-system = [ flit-core ];
    dependencies = [
      annotated-types
      pydantic
      rich
    ];
    propagatedBuildInputs = [
      cudaPackages.cuda_cuobjdump
      nixVersions.latest
      patchelf
    ];
    pythonImportsCheck = [ finalAttrs.pname ];
    nativeCheckInputs = [
      pyright
    ];
    passthru.optional-dependencies.dev = [
      pyright
      ruff
    ];
    doCheck = true;
    checkPhase =
      # preCheck
      ''
        runHook preCheck
      ''
      # Check with pyright
      + ''
        echo "Typechecking with pyright"
        pyright --warnings
        echo "Verifying type completeness with pyright"
        pyright --verifytypes ${finalAttrs.pname} --ignoreexternal
      ''
      # postCheck
      + ''
        runHook postCheck
      '';
    postInstall = ''
      wrapProgram "$out/bin/update-custom-index" \
        --prefix PATH : "${
          makeBinPath [
            cudaPackages.cuda_cuobjdump
            nixVersions.latest
            patchelf
          ]
        }"
    '';
    meta = with lib; {
      inherit (pyprojectAttrs.project) description;
      homepage = pyprojectAttrs.project.urls.Homepage;
      maintainers = with maintainers; [ connorbaker ];
    };
  };
in
buildPythonPackage finalAttrs
