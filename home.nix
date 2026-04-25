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
    ./modules/shell.nix
    ./modules/tmux.nix
    ./modules/terminal.nix
    ./modules/packages.nix
    ./modules/neovim
    ./modules/claude-code.nix
    ./modules/television.nix
  ];

  home.stateVersion = "24.11";

  home.sessionVariables = lib.mkMerge [
    {
      NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
      EDITOR = "${config.home.homeDirectory}/.config/home-manager/scripts/nvim-editor-popup.sh";
      VISUAL = "${config.home.homeDirectory}/.config/home-manager/scripts/nvim-editor-popup.sh";
    }
    (lib.mkIf pkgs.stdenv.isLinux {
      KITTY_DISABLE_WAYLAND = "1";
    })
  ];

  # PipeWire echo cancellation — Linux only (creates virtual mic with system audio removed)
  home.file.".config/pipewire/pipewire.conf.d/echo-cancel.conf" = lib.mkIf pkgs.stdenv.isLinux {
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

  # Symlink nix-profile .desktop files into GNOME app menu — Linux only
  home.activation.copyDesktopFiles = lib.mkIf pkgs.stdenv.isLinux (
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
