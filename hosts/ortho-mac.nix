{
  config,
  pkgs,
  lib,
  ...
}: {
  # No darwin-only modules yet. Add here when darwin-specific modules are created.
  imports = [];

  home.username = "ortho";
  home.homeDirectory = "/Users/ortho";
}
