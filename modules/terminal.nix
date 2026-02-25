{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;
    themeFile = "Dark_Pastel";
    package = config.lib.nixGL.wrap pkgs.kitty;
  };
}
