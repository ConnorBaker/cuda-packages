{
  buildPythonPackage,
  docstring-parser,
  fetchFromGitHub,
  lib,
  pytestCheckHook,
  pythonOlder,
  setuptools,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "pyglove";
  version = "0.4.4";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "google";
    repo = "pyglove";
    tag = "v0.4.4";
    hash = "sha256-WCUEmmCZWEricwXgA0gm1judJMjyMhCWdCIG6gIjqlc=";
  };

  pyproject = true;

  build-system = [ setuptools ];

  postPatch = ''
    nixLog "fixing TMPDIR assumption in $PWD/pyglove/core/io/file_system_test.py"
    substituteInPlace "$PWD/pyglove/core/io/file_system_test.py" \
      --replace-fail \
        "['/tmp/dir1/a', '/tmp/dir1/file2']" \
        "[f'{tempfile.gettempdir()}/dir1/a', f'{tempfile.gettempdir()}/dir1/file2']"
  '';

  dependencies = [ docstring-parser ];

  enableParallelBuilding = true;

  doCheck = true;

  nativeCheckInputs = [ pytestCheckHook ];

  pythonImportsCheck = [ "pyglove" ];

  meta = {
    description = "Manipulating python programs";
    homepage = "https://github.com/google/pyglove";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
