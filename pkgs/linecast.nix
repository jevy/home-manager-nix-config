# linecast: weather, tides, sun, moon and maps drawn for the terminal.
# Pure Python, hatchling, no runtime deps on Linux/Darwin (the tzdata and
# truststore deps in pyproject.toml are `sys_platform == 'win32'` only).
{
  lib,
  python3Packages,
  fetchFromGitHub,
  installShellFiles,
  versionCheckHook,
}:

python3Packages.buildPythonApplication rec {
  pname = "linecast";
  version = "2.1.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "ashuttl";
    repo = "linecast";
    tag = "v${version}";
    hash = "sha256-9y84PWXiwRh+yXN5rkM3K4269+qNer94oQ1SPpBbI4c=";
  };

  build-system = [ python3Packages.hatchling ];

  nativeBuildInputs = [ installShellFiles ];

  # The binary dispatches on argv[0], so `weather`, `moon` etc. work from a
  # symlink. Upstream deliberately ships only `linecast` (those names collide
  # with other packages), so completions are all we add here.
  postInstall = ''
    installShellCompletion --cmd linecast \
      --bash <($out/bin/linecast completion bash) \
      --zsh <($out/bin/linecast completion zsh) \
      --fish <($out/bin/linecast completion fish)
  '';

  # tests/conftest.py blocks the network and relocates HOME; integration tests
  # are excluded by the addopts in pyproject.toml.
  nativeCheckInputs = [
    python3Packages.pytestCheckHook
    versionCheckHook
  ];
  versionCheckProgramArg = "--version";

  pythonImportsCheck = [ "linecast" ];

  meta = {
    description = "Weather, tides, the sun, the moon, and maps, drawn for the terminal";
    homepage = "https://github.com/ashuttl/linecast";
    changelog = "https://github.com/ashuttl/linecast/blob/v${version}/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "linecast";
    platforms = lib.platforms.unix;
  };
}
