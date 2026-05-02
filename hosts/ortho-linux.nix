{
  config,
  pkgs,
  lib,
  nixgl,
  ...
}: {
  imports = [
    ../modules/gnome.nix
    ../modules/theme.nix
    ../modules/music.nix
    ../modules/piper.nix
    ../modules/llm.nix
    ../modules/obsidian-backup.nix
    ../modules/kitty-session.nix
    ../modules/firefox.nix
  ];

  home.username = "ortho";
  home.homeDirectory = "/home/ortho";

  # allowUnfree lives here (not in home.nix) so it only applies to the standalone
  # Linux HM config where nixpkgs is managed by home-manager itself.
  # On darwin, nix-darwin's nixpkgs.config.allowUnfree = true handles it.
  nixpkgs.config.allowUnfree = true;

  # GPU support for non-NixOS Linux via nixGL (wraps OpenGL/Vulkan apps).
  targets.genericLinux.enable = true;
  targets.genericLinux.nixGL.packages = nixgl.packages;
}
