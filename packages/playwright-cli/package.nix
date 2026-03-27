{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  playwright-driver,
  playwright-test,
}:
buildNpmPackage rec {
  pname = "playwright-cli";
  version = "0.1.1";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "playwright-cli";
    tag = "v${version}";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  npmDepsHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";

  dontNpmBuild = true;

  postInstall = ''
    rm -rf "$out/lib/node_modules/@playwright/cli/node_modules/playwright"
    rm -rf "$out/lib/node_modules/@playwright/cli/node_modules/playwright-core"
    ln -s ${playwright-test}/lib/node_modules/playwright \
      "$out/lib/node_modules/@playwright/cli/node_modules/playwright"
    ln -s ${playwright-test}/lib/node_modules/playwright-core \
      "$out/lib/node_modules/@playwright/cli/node_modules/playwright-core"

    wrapProgram $out/bin/playwright-cli \
      --set PLAYWRIGHT_BROWSERS_PATH ${playwright-driver.browsers}
  '';

  meta = {
    description = "Playwright CLI for browser automation";
    homepage = "https://github.com/microsoft/playwright-cli";
    license = lib.licenses.asl20;
    mainProgram = "playwright-cli";
  };
}
