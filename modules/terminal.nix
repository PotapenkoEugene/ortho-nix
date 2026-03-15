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
    settings = {
      startup_session = "~/.config/kitty/session.conf";
      allow_remote_control = "socket-only";
      listen_on = "unix:/tmp/kitty-main";
    };
  };
}
