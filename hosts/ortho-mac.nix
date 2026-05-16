{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [../modules/ollama.nix];

  home.username = "ortho";
  home.homeDirectory = "/Users/ortho";
}
