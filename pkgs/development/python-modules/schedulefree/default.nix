{
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  lib,
  torch,
  typing-extensions,
}:
buildPythonPackage {
  __structuredAttrs = true;

  pname = "schedulefree";
  version = "0-unstable-2025-04-11";

  src = fetchFromGitHub {
    owner = "facebookresearch";
    repo = "schedule_free";
    rev = "d407c270af9eced81c9107c14783a34268559769";
    hash = "sha256-95he9Wv74u1hVLFnUqtPpc73JP7bnD9iccFbm4RkrcE=";
  };

  pyproject = true;

  build-system = [ hatchling ];

  dependencies = [
    torch
    typing-extensions
  ];

  doCheck = false; # No tests

  pythonImportsCheck = [ "schedulefree" ];

  meta = {
    description = "Schedule-Free Optimization in PyTorch";
    homepage = "https://github.com/facebookresearch/schedule_free";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    maintainers = with lib.maintainers; [ connorbaker ];
  };
}
