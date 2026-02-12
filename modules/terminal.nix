{
  config,
  pkgs,
  lib,
  ...
}: {
  programs.kitty = {
    enable = true;
    themeFile = "Dark_Pastel";
  };
}
