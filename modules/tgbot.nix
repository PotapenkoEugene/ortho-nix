{
  config,
  pkgs,
  lib,
  ...
}: let
  repoDir = "/Users/ortho/tgbot";
  dbDir = "/Users/ortho/Library/Application Support/tgbot";
  logDir = "/Users/ortho/Library/Logs";

  tgbotRun = pkgs.writeShellApplication {
    name = "tgbot-run";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail
      read -r BOT_TOKEN < /run/secrets/tgbot/bot_token || true
      export BOT_TOKEN
      export OLLAMA_URL="http://localhost:11434"
      export OLLAMA_MODEL="qwen2.5:14b-instruct"
      export DB_PATH="${dbDir}/tgbot.db"
      mkdir -p "${dbDir}"
      cd "${repoDir}"
      export PYTHONPATH="${repoDir}/src"
      export PYTHONUNBUFFERED=1
      exec "${repoDir}/.venv/bin/python" -m tgbot.main
    '';
  };

  tgbotUpdate = pkgs.writeShellApplication {
    name = "tgbot-update";
    runtimeInputs = [pkgs.git pkgs.uv];
    text = ''
      set -euo pipefail
      cd "${repoDir}"
      git pull --ff-only
      uv sync --frozen
      launchctl kickstart -k "gui/$(id -u)/com.ortho.tgbot"
      echo "tgbot updated and restarted"
    '';
  };
in
  lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/mac.yaml) {
    environment.systemPackages = [tgbotRun tgbotUpdate];

    launchd.user.agents.tgbot = {
      serviceConfig = {
        Label = "com.ortho.tgbot";
        ProgramArguments = ["${tgbotRun}/bin/tgbot-run"];
        EnvironmentVariables = {
          HOME = "/Users/ortho";
        };
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        ThrottleInterval = 10;
        StandardOutPath = "${logDir}/tgbot.log";
        StandardErrorPath = "${logDir}/tgbot.err";
      };
    };
  }
