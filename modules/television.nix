{
  config,
  pkgs,
  lib,
  ...
}: {
  # Television (tv) fuzzy finder — cable channels and custom overrides

  home.file = {
    # Custom docker-containers channel: status in display, inspect in preview
    ".config/television/cable/docker-containers.toml" = {
      source = ../television/docker-containers.toml;
      force = true; # Override built-in channel installed by tv update-channels
    };
  };

  # Install cable channels on every switch; patch tmux-sessions to use switch-client
  home.activation.tvUpdateChannels = lib.hm.dag.entryAfter ["installPackages"] ''
    if command -v tv &>/dev/null; then
      tv update-channels 2>/dev/null || true
      CABLE="${config.home.homeDirectory}/.config/television/cable"
      if [ -f "$CABLE/tmux-sessions.toml" ]; then
        sed -i 's/tmux attach-session -t/tmux switch-client -t/g' "$CABLE/tmux-sessions.toml"
      fi
    fi
  '';
}
