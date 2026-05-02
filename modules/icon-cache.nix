{
  config,
  pkgs,
  lib,
  ...
}: {
  # GTK icon cache for nix-on-non-NixOS: nix profile dirs are read-only, so
  # symlink icon size dirs and index.theme into writable ~/.local/share/icons/hicolor/
  # then build the cache there.
  home.activation.rebuildIconCache = lib.hm.dag.entryAfter ["linkGeneration"] ''
    nix_hicolor="${config.home.profileDirectory}/share/icons/hicolor"
    local_hicolor="$HOME/.local/share/icons/hicolor"

    if [ -d "$nix_hicolor" ]; then
      mkdir -p "$local_hicolor"
      for d in "$nix_hicolor"/*/; do
        name="$(basename "$d")"
        target="$local_hicolor/$name"
        [ -e "$target" ] || ln -s "$d" "$target"
      done
      [ -e "$local_hicolor/index.theme" ] || ln -s "$nix_hicolor/index.theme" "$local_hicolor/index.theme"
      run ${pkgs.gtk3}/bin/gtk-update-icon-cache -f "$local_hicolor" 2>/dev/null || true
    fi
  '';
}
