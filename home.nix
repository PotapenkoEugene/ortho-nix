{
  config,
  pkgs,
  lib,
  ...
}: {
  # Cross-platform modules — imported on all hosts.
  # Linux-only modules (gnome, theme, music, piper, llm, obsidian-backup, kitty-session)
  # are imported from hosts/ortho-linux.nix.
  imports = [
    ./modules/options.nix # ortho.headless flag — must be first
    ./modules/shell.nix
    ./modules/tmux.nix
    # terminal.nix (kitty) intentionally NOT here — imported by each desktop host file
    ./modules/packages.nix
    ./modules/neovim
    ./modules/claude-code.nix
    ./modules/television.nix
    ./modules/secrets.nix
  ];

  home.stateVersion = "24.11";

  home.sessionVariables = lib.mkMerge [
    {
      NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
      EDITOR = "${config.home.homeDirectory}/.config/home-manager/scripts/nvim-editor-popup.sh";
      VISUAL = "${config.home.homeDirectory}/.config/home-manager/scripts/nvim-editor-popup.sh";
    }
    (lib.mkIf (pkgs.stdenv.isLinux && !config.ortho.headless) {
      KITTY_DISABLE_WAYLAND = "1";
    })
  ];

  # PipeWire echo cancellation — Linux desktop only (not on headless server)
  home.file.".config/pipewire/pipewire.conf.d/echo-cancel.conf" = lib.mkIf (pkgs.stdenv.isLinux && !config.ortho.headless) {
    text = ''
      context.modules = [
        {
          name = libpipewire-module-echo-cancel
          args = {
            library.name = aec/libspa-aec-webrtc
            monitor.mode = true
            audio.rate = 48000
            audio.channels = 1
            source.props = {
              node.name = "echo-cancel-source"
              node.description = "Echo-Cancelled Mic"
            }
          }
        }
      ]
    '';
  };

  # Symlink nix-profile .desktop files into GNOME app menu — Linux desktop only
  home.activation.copyDesktopFiles = lib.mkIf (pkgs.stdenv.isLinux && !config.ortho.headless) (
    lib.hm.dag.entryAfter ["installPackages"] ''
      if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ]; then
        if [ ! -d "${config.home.homeDirectory}/.local/share/applications" ]; then
          mkdir "${config.home.homeDirectory}/.local/share/applications"
        fi
        if [ -d "${config.home.homeDirectory}/.local/share/applications/nix" ]; then
          rm -rf "${config.home.homeDirectory}/.local/share/applications/nix"
        fi
        ln -sf "${config.home.homeDirectory}/.nix-profile/share/applications" \
          ${config.home.homeDirectory}/.local/share/applications/nix
      fi
    ''
  );

  programs.home-manager.enable = true;
}
