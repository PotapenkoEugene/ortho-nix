{
  config,
  lib,
  pkgs,
  ...
}:
lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/common.yaml) {
  launchd.agents.askbot = {
    enable = true;
    config = {
      Label = "com.ortho.askbot";
      Program = "${pkgs.writeShellApplication {
        name = "askbot-run";
        runtimeInputs = [];
        text = ''
          export PATH="${config.home.homeDirectory}/.local/bin:$PATH"
          source "${config.home.homeDirectory}/.config/sops-nix/secrets/rendered/secrets.env" || true
          cd "${config.home.homeDirectory}/Projects/orthi-askbot"
          export PYTHONPATH="${config.home.homeDirectory}/Projects/orthi-askbot/src"
          export PYTHONUNBUFFERED=1
          exec .venv/bin/python -m askbot.main
        '';
      }}/bin/askbot-run";
      RunAtLoad = true;
      KeepAlive = {
        SuccessfulExit = false;
        Crashed = true;
      };
      StandardOutPath = "${config.home.homeDirectory}/Library/Logs/askbot.log";
      StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/askbot.err";
      ThrottleInterval = 10;
      WorkingDirectory = "${config.home.homeDirectory}/Projects/orthi-askbot";
    };
  };

  home.packages = [
    (pkgs.writeShellApplication {
      name = "askbot-update";
      runtimeInputs = [pkgs.git pkgs.uv];
      text = ''
        cd ~/Projects/orthi-askbot
        git pull --ff-only
        uv sync --frozen
        launchctl kickstart -k "gui/$(id -u)/com.ortho.askbot"
      '';
    })
  ];
}
