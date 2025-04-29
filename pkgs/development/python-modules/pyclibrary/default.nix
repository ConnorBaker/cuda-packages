{
  buildPythonPackage,
  fetchFromGitHub,
  lib,
  pyparsing,
  pytestCheckHook,
  pythonOlder,
  setuptools-scm,
  setuptools,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "pyclibrary";
  # NOTE: Cannot modify to use the -unstable-2025-04-09 suffix because pyproject uses the version
  # attribute.
  version = "0.2.2";

  src = fetchFromGitHub {
    owner = "MatthieuDartiailh";
    repo = "pyclibrary";
    # NOTE: Includes simplifications not yet available in a release (latest is 0.2.2).
    rev = "4e1e243a0bdfefa188d93ebdf3b60c6861244855";
    hash = "sha256-hoGfHqGqhIxoyJfYYJcSOp2laf78Fx02oPWj54Q16us=";
  };

  disabled = pythonOlder "3.7";

  pyproject = true;

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [ pyparsing ];

  nativeCheckInputs = [ pytestCheckHook ];

  doCheck = true;

  pythonImportsCheck = [ "pyclibrary" ];

  meta = {
    description = "C parser and ctypes automation for python";
    homepage = "https://github.com/MatthieuDartiailh/pyclibrary";
    license = lib.licenses.mit;
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
