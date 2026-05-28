{
  config,
  pkgs,
  lib,
  ...
}: let
  repoDir = "/Users/ortho/Projects/TGbotNotebookLM";
  dbDir = "/Users/ortho/Library/Application Support/nlmbot";
  logDir = "/Users/ortho/Library/Logs";
  orthidianDir = "/Users/ortho/Orthidian";
  podcastsDir = "/Users/ortho/Podcasts/notebooklm-popsci";

  nlmbotRun = pkgs.writeShellApplication {
    name = "nlmbot-run";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail
      read -r BOT_TOKEN < "$HOME/.config/sops-nix/secrets/cfbot/bot_token" || true
      export BOT_TOKEN
      export ALLOWED_USER_ID="330794264"
      # shellcheck source=/dev/null
      [ -f "$HOME/.config/sops-nix/secrets/rendered/secrets.env" ] && source "$HOME/.config/sops-nix/secrets/rendered/secrets.env"
      export PATH="$HOME/.local/bin:/etc/profiles/per-user/ortho/bin:/run/current-system/sw/bin:$PATH"
      export DB_PATH="${dbDir}/nlmbot.db"
      export QUEUE_PATH="${orthidianDir}/ideas/podcast-queue.md"
      export PODCASTS_DIR="${podcastsDir}"
      export NLM_PROJECT_DIR="${repoDir}"
      export DAILY_RUN_HOUR="5"
      export PODCAST_TARGET="3"
      mkdir -p "${dbDir}"
      mkdir -p "${podcastsDir}"
      mkdir -p "${orthidianDir}/ideas"
      cd "${repoDir}"
      export PYTHONPATH="${repoDir}/src"
      export PYTHONUNBUFFERED=1
      exec "${repoDir}/.venv/bin/python" -m nlmbot.main
    '';
  };

  nlmbotUpdate = pkgs.writeShellApplication {
    name = "nlmbot-update";
    runtimeInputs = [pkgs.git pkgs.uv pkgs.rsync];
    text = ''
      set -euo pipefail
      cd "${repoDir}"
      # Sync from Linux dev machine (git push not available — no GitHub SSH key on this host)
      rsync -av --exclude='.venv' --exclude='__pycache__' ortho@ortho-linux:Documents/Projects/TGbotNotebookLM/ "${repoDir}/"
      uv sync --frozen
      launchctl kickstart -k "gui/$(id -u)/com.ortho.nlmbot"
      echo "nlmbot updated and restarted"
    '';
  };
in
  lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/common.yaml) {
    environment.systemPackages = [nlmbotRun nlmbotUpdate];

    launchd.user.agents.nlmbot = {
      serviceConfig = {
        Label = "com.ortho.nlmbot";
        ProgramArguments = ["${nlmbotRun}/bin/nlmbot-run"];
        EnvironmentVariables = {
          HOME = "/Users/ortho";
        };
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        ThrottleInterval = 10;
        StandardOutPath = "${logDir}/nlmbot.log";
        StandardErrorPath = "${logDir}/nlmbot.err";
      };
    };
  }
