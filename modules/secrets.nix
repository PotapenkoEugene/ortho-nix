{
  config,
  pkgs,
  lib,
  ...
}:
lib.mkIf (pkgs.stdenv.isDarwin && builtins.pathExists ../secrets/mac.yaml) {
  sops = {
    defaultSopsFile = ../secrets/mac.yaml;
    age.keyFile = "/Users/ortho/.config/sops/age/keys.txt";
    age.generateKey = false;

    secrets."tgbot/bot_token" = {
      owner = "ortho";
      group = "staff";
      mode = "0400";
    };
  };
}
