{
  pkgs,
  lib,
  ...
}: let
  repoDir = "/Users/ortho/Projects/orthi-askbot";
  logDir = "/Users/ortho/Library/Logs";

  askbotRun = pkgs.writeShellApplication {
    name = "askbot-run";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail
      # shellcheck source=/dev/null
      [ -f "$HOME/.config/sops-nix/secrets/rendered/secrets.env" ] && source "$HOME/.config/sops-nix/secrets/rendered/secrets.env"
      export PATH="$HOME/.local/bin:/etc/profiles/per-user/ortho/bin:/run/current-system/sw/bin:$PATH"
      cd "${repoDir}"
      export PYTHONPATH="${repoDir}/src"
      export PYTHONUNBUFFERED=1
      exec "${repoDir}/.venv/bin/python" -m askbot.main
    '';
  };

  askbotUpdate = pkgs.writeShellApplication {
    name = "askbot-update";
    runtimeInputs = [pkgs.git pkgs.uv];
    text = ''
      set -euo pipefail
      cd "${repoDir}"
      git pull --ff-only
      uv sync --frozen
      launchctl kickstart -k "gui/$(id -u)/com.ortho.askbot"
      echo "askbot updated and restarted"
    '';
  };
in
  lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/common.yaml) {
    environment.systemPackages = [askbotRun askbotUpdate];

    launchd.user.agents.askbot = {
      serviceConfig = {
        Label = "com.ortho.askbot";
        ProgramArguments = ["${askbotRun}/bin/askbot-run"];
        EnvironmentVariables = {
          HOME = "/Users/ortho";
        };
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        ThrottleInterval = 10;
        StandardOutPath = "${logDir}/askbot.log";
        StandardErrorPath = "${logDir}/askbot.err";
      };
    };
  }
