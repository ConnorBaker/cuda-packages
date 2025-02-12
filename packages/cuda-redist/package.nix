{
  lib,
  makeWrapper,
  nixVersions,
  pyright,
  python3,
}:
let
  inherit (lib.fileset) toSource unions;
  inherit (lib.strings) makeBinPath;
  inherit (lib.trivial) importTOML;
  inherit (python3.pkgs)
    annotated-types
    buildPythonPackage
    flit-core
    pydantic
    rich
    ruff
    ;
  pyprojectAttrs = importTOML ./pyproject.toml;
  finalAttrs = {
    pname = pyprojectAttrs.project.name;
    inherit (pyprojectAttrs.project) version;
    pyproject = true;
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
    propagatedBuildInputs = [ nixVersions.latest ];
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
      ''
      # postCheck
      + ''
        runHook postCheck
      '';
    postInstall = ''
      wrapProgram "$out/bin/update-custom-index" \
        --prefix PATH : "${makeBinPath [ nixVersions.latest ]}"
    '';
    meta = {
      inherit (pyprojectAttrs.project) description;
      homepage = pyprojectAttrs.project.urls.Homepage;
      maintainers = with lib.maintainers; [ connorbaker ];
    };
  };
in
buildPythonPackage finalAttrs
