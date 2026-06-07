{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./options.nix
    ./plugins.nix
    ./keymaps.nix
    ./lua.nix
  ];

  programs.nixvim = {
    enable = true;
    # magick (ImageMagick lua binding) only needed for image.nvim — skip on headless server
    extraLuaPackages = ps: lib.optionals (!config.ortho.headless) [ps.magick];
  };
}
