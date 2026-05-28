{
  config,
  pkgs,
  lib,
  ...
}: let
  repoDir = "/Users/ortho/Projects/TGbotMessageToHebrew";
  dbDir = "/Users/ortho/Library/Application Support/tgbot";
  logDir = "/Users/ortho/Library/Logs";

  tgbotRun = pkgs.writeShellApplication {
    name = "tgbot-run";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail
      read -r BOT_TOKEN < "$HOME/.config/sops-nix/secrets/tgbot/bot_token" || true
      export BOT_TOKEN
      # Load API keys from sops-managed secrets.env
      # shellcheck source=/dev/null
      [ -f "$HOME/.config/sops-nix/secrets/rendered/secrets.env" ] && source "$HOME/.config/sops-nix/secrets/rendered/secrets.env"
      # claude is installed via native installer at ~/.local/bin/claude (auto-updating)
      export PATH="$HOME/.local/bin:/etc/profiles/per-user/ortho/bin:/run/current-system/sw/bin:$PATH"
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
  lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/common.yaml) {
    home.packages = [tgbotRun tgbotUpdate];

    launchd.agents.tgbot = {
      enable = true;
      config = {
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
