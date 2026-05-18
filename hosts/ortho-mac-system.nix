{
  pkgs,
  lib,
  ...
}: let
  mlxPython = pkgs.python313.withPackages (ps: [ps.mlx-lm]);
in {
  imports = [
    ../modules/secrets.nix
    ../modules/tgbot.nix
  ];

  # Set platform so nix-darwin.lib.darwinSystem doesn't require a `system` arg.
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";

  # Required for launchd.user.agents and other user-scoped options (nix-darwin runs activation as root now).
  system.primaryUser = "ortho";

  # Declare the primary user so home-manager knows where to install files.
  users.users.ortho = {
    name = "ortho";
    home = "/Users/ortho";
    shell = pkgs.bash;
  };

  # Determinate Nix manages the installation — disable nix-darwin's conflicting management.
  nix.enable = false;

  # nix-darwin state version — separate from home-manager's stateVersion.
  # 6 is current as of nix-darwin 25.05; bump only on instructed migrations.
  system.stateVersion = 6;

  # Register bash in /etc/shells (required when using bash as default shell).
  programs.bash.enable = true;

  # Allow ortho to run darwin-rebuild without password (required for remote SSH automation).
  security.sudo.extraConfig = ''
    ortho ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
  '';

  # MLX-LM server — serves Qwen3-30B-A3B-Instruct via OpenAI-compatible API on :8765.
  # Listens on all interfaces so Tailscale IP is reachable from Linux box.
  # Model auto-downloaded from HuggingFace on first start (~17GB, may take a while).
  launchd.user.agents.mlx = {
    serviceConfig = {
      Label = "com.ortho.mlx";
      ProgramArguments = [
        "${mlxPython}/bin/python"
        "-m"
        "mlx_lm.server"
        "--model"
        "mlx-community/Qwen3-30B-A3B-Instruct-4bit"
        "--host"
        "0.0.0.0"
        "--port"
        "8765"
        "--log-level"
        "INFO"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 30;
      EnvironmentVariables = {
        HF_HOME = "/Users/ortho/.cache/huggingface";
        PATH = "/usr/bin:/bin:/usr/sbin:/sbin";
      };
      StandardOutPath = "/Users/ortho/Library/Logs/mlx.log";
      StandardErrorPath = "/Users/ortho/Library/Logs/mlx.err";
    };
  };

  # Ollama LLM daemon — auto-starts on login, restarts if killed.
  # Listens on all interfaces (OLLAMA_HOST=0.0.0.0) so Tailscale IP is reachable from Linux.
  launchd.user.agents.ollama = {
    serviceConfig = {
      Label = "com.ortho.ollama";
      ProgramArguments = [
        "${pkgs.ollama}/bin/ollama"
        "serve"
      ];
      RunAtLoad = true;
      KeepAlive = true;
      EnvironmentVariables = {
        OLLAMA_HOST = "0.0.0.0:11434";
        OLLAMA_KEEP_ALIVE = "-1";
        OLLAMA_MAX_LOADED_MODELS = "3";
      };
      StandardOutPath = "/Users/ortho/Library/Logs/ollama.log";
      StandardErrorPath = "/Users/ortho/Library/Logs/ollama.log";
    };
  };
}
