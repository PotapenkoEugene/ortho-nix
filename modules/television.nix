{
  config,
  pkgs,
  lib,
  ...
}: {
  # Television (tv) fuzzy finder — cable channels and custom overrides

  home.file = {
    # Custom docker-images channel: size/age stats, drill-down to containers
    ".config/television/cable/docker-images.toml" = {
      source = ../television/docker-images.toml;
      force = true;
    };
    # Custom docker-containers channel: image in display for drill-down filtering, cycling previews
    ".config/television/cable/docker-containers.toml" = {
      source = ../television/docker-containers.toml;
      force = true;
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
