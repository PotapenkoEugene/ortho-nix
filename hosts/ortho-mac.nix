{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../modules/ollama.nix
    ../modules/mlx.nix
  ];

  home.username = "ortho";
  home.homeDirectory = "/Users/ortho";
}
