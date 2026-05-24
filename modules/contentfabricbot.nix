{
  config,
  pkgs,
  lib,
  ...
}: let
  repoDir = "/Users/ortho/Projects/ContentFabricBot";
  dbDir = "/Users/ortho/Library/Application Support/cfbot";
  logDir = "/Users/ortho/Library/Logs";
  pipelineLib = "/Users/ortho/.claude/skills/_notebooklm-podcast-lib/scripts";
  podcastRoot = "/Users/ortho/NotebookLM_pipelines";
  knowledgeDir = "/Users/ortho/Orthidian/knowledge/_popsci-podcasts";

  cfbotRun = pkgs.writeShellApplication {
    name = "cfbot-run";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      set -euo pipefail
      read -r BOT_TOKEN < "$HOME/.config/sops-nix/secrets/cfbot/bot_token" || true
      export BOT_TOKEN
      # Load API keys (GROQ_API_KEY etc.) from sops-managed secrets.env
      # shellcheck source=/dev/null
      [ -f "$HOME/.config/sops-nix/secrets/rendered/secrets.env" ] && source "$HOME/.config/sops-nix/secrets/rendered/secrets.env"
      export PATH="/etc/profiles/per-user/ortho/bin:/run/current-system/sw/bin:$PATH"
      export DB_PATH="${dbDir}/cfbot.db"
      export PIPELINE_LIB="${pipelineLib}"
      export PODCAST_ROOT="${podcastRoot}"
      export KNOWLEDGE_DIR="${knowledgeDir}"
      mkdir -p "${dbDir}"
      cd "${repoDir}"
      export PYTHONPATH="${repoDir}/src"
      export PYTHONUNBUFFERED=1
      exec "${repoDir}/.venv/bin/python" -m cfbot.main
    '';
  };

  cfbotUpdate = pkgs.writeShellApplication {
    name = "cfbot-update";
    runtimeInputs = [pkgs.uv pkgs.openssh];
    text = ''
      set -euo pipefail
      # Sync latest code from Linux dev machine (ortho-nix) via rsync
      rsync -av --exclude '.venv' --exclude '__pycache__' --exclude '*.pyc' --exclude '.git' \
        "ortho-nix:/home/ortho/Documents/Projects/ContentFabricBot/" "${repoDir}/"
      cd "${repoDir}"
      uv sync --frozen
      uv pip install -e . -q
      launchctl kickstart -k "gui/$(id -u)/com.ortho.cfbot"
      echo "cfbot updated and restarted"
    '';
  };
in
  lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/common.yaml) {
    environment.systemPackages = [cfbotRun cfbotUpdate];

    launchd.user.agents.cfbot = {
      serviceConfig = {
        Label = "com.ortho.cfbot";
        ProgramArguments = ["${cfbotRun}/bin/cfbot-run"];
        EnvironmentVariables = {
          HOME = "/Users/ortho";
        };
        RunAtLoad = true;
        KeepAlive = {
          SuccessfulExit = false;
          Crashed = true;
        };
        ThrottleInterval = 10;
        StandardOutPath = "${logDir}/cfbot.log";
        StandardErrorPath = "${logDir}/cfbot.err";
      };
    };
  }
