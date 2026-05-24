{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [../modules/ollama.nix ../modules/orthi-brain.nix];

  home.username = "ortho";
  home.homeDirectory = "/Users/ortho";

  # If the repo was cloned into a subdirectory (ortho-nix/), symlink the key
  # runtime paths up to where settings.json hardcodes them.
  home.activation.linkHmRuntimeDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    hm_dir="/Users/ortho/.config/home-manager"
    src="$hm_dir/ortho-nix"
    if [ -d "$src" ]; then
      for d in scripts claude-code sounds; do
        if [ -d "$src/$d" ] && [ ! -e "$hm_dir/$d" ]; then
          ln -sfn "$src/$d" "$hm_dir/$d"
        fi
      done
    fi
  '';
}
