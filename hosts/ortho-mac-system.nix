{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/tgbot.nix
    ../modules/nlmbot.nix
    ../modules/askbot.nix
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

  # System timezone — declarative so it survives rebuilds and doesn't drift.
  time.timeZone = "Asia/Jerusalem";

  # Register bash in /etc/shells so users.users.ortho.shell takes effect.
  # macOS rejects a login shell not listed in /etc/shells; environment.shells
  # adds the nix bash path there during activation.
  programs.bash.enable = true;
  environment.shells = [pkgs.bash];

  # Allow ortho to run darwin-rebuild without password (required for remote SSH automation).
  security.sudo.extraConfig = ''
    ortho ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
  '';

  # Switch the login shell to the nix-managed bash during activation.
  # dscl write is needed because ortho is a pre-existing macOS user (not managed
  # by users.knownUsers), so nix-darwin's user module skips the UserShell update.
  # system.activationScripts is internal — use the public postActivation hook instead.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    BASH=/run/current-system/sw/bin/bash
    CURRENT_SHELL=$(/usr/bin/dscl . -read /Users/ortho UserShell 2>/dev/null | awk '{print $2}')
    if [ "$CURRENT_SHELL" != "$BASH" ]; then
      echo "postActivation: setting login shell to $BASH" >&2
      /usr/bin/dscl . -change /Users/ortho UserShell "$CURRENT_SHELL" "$BASH"
    fi
  '';

  # skhd global hotkeys — cmd+alt-n opens personal daily note.
  # IMPORTANT: after darwin-rebuild, grant Accessibility permission to skhd in
  # System Settings > Privacy & Security > Accessibility (cannot be scripted).
  services.skhd = {
    enable = true;
    skhdConfig = ''
      # Personal daily note: cmd+alt-n → kitty running personal-note-open.sh
      cmd + alt - n : /Users/ortho/.nix-profile/bin/kitty /Users/ortho/.config/home-manager/scripts/personal-note-open.sh
    '';
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
