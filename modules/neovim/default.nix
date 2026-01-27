{ config, pkgs, lib, ... }:
{
  imports = [
    ./options.nix
    ./plugins.nix
    ./keymaps.nix
    ./lua.nix
  ];

  programs.nixvim = {
    enable = true;
  };
}
