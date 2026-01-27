{ config, pkgs, lib, ... }:
{
  nixGL = {
    packages = pkgs.nixgl;
    defaultWrapper = "mesa";
    offloadWrapper = "nvidiaPrime";
    installScripts = [
      "mesa"
      "nvidiaPrime"
    ];
  };

  #    programs.ghostty.package = config.lib.nixGL.wrap pkgs.ghostty;
  #    programs.ghostty = {
  #	enable = true;
  #    };
  programs.kitty.package = config.lib.nixGL.wrap pkgs.kitty;
  programs.kitty = {
    enable = true;
    themeFile = "Dark_Pastel";
  };
}
