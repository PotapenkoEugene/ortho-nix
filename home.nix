{
  config,
  pkgs,
  lib,
  nixgl,
  ...
}: {
  imports = [
    ./modules/gnome.nix
    ./modules/theme.nix
    ./modules/shell.nix
    ./modules/music.nix
    ./modules/tmux.nix
    ./modules/terminal.nix
    ./modules/packages.nix
    ./modules/neovim
    ./modules/claude-code.nix
    ./modules/piper.nix
    ./modules/llm.nix
  ];

  # GPU support for non-NixOS via nixGL
  targets.genericLinux.enable = true;
  targets.genericLinux.nixGL.packages = nixgl.packages;

  home.username = "ortho";
  home.homeDirectory = "/home/ortho";
  home.stateVersion = "24.11"; # Please read the comment before changing.

  home.sessionVariables = {
    #GTK_THEME = "Adwaita-dark";
    #PKG_CONFIG_PATH = "${pkgs.imagemagick.dev}/lib/pkgconfig:/usr/lib/x86_64-linux-gnu/pkgconfig:/usr/lib/pkgconfig:/usr/share/pkgconfig"; # for config ImageMagick-dev for image.nvim, here i add system paths to libs (due to problem of installing them via nix)
    #	QT_QPA_PLATFORMTHEME = "qt6ct";
    KITTY_DISABLE_WAYLAND = "1";
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  };

  nixpkgs.config.allowUnfree = true;

  home.file = {
    # PipeWire echo cancellation — creates virtual mic with system audio removed
    ".config/pipewire/pipewire.conf.d/echo-cancel.conf".text = ''
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

  home.activation.copyDesktopFiles = lib.hm.dag.entryAfter ["installPackages"] ''
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
  '';

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
