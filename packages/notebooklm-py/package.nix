{
  lib,
  python313Packages,
  fetchFromGitHub,
}:
python313Packages.buildPythonPackage rec {
  pname = "notebooklm-py";
  version = "0.3.4";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "teng-lin";
    repo = "notebooklm-py";
    rev = "v${version}";
    hash = "sha256-vrCgOYQngSmsv4rnl6CTNk26DB+BxgplwkVfznVbBZo=";
  };

  build-system = with python313Packages; [
    hatchling
    hatch-fancy-pypi-readme
  ];

  dependencies = with python313Packages; [
    httpx
    click
    rich
    playwright # required for notebooklm login browser flow
  ];

  # Tests require live Google auth + network
  doCheck = false;

  meta = {
    description = "Unofficial Python API and CLI for Google NotebookLM";
    homepage = "https://github.com/teng-lin/notebooklm-py";
    license = lib.licenses.mit;
    mainProgram = "notebooklm";
  };
}
