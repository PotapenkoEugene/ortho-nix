# Headless x86_64-linux lab server — rootless nix-portable install.
# Nix data: /mnt/data/eugene/Tools/.nix-portable (NP_LOCATION=/mnt/data/eugene/Tools)
# Activation: home-manager switch --flake .  (username auto-matches "potapgene")
{...}: {
  home.username = "potapgene";
  home.homeDirectory = "/home/potapgene";

  ortho.headless = true;

  nixpkgs.config.allowUnfree = true;

  # genericLinux: fixes XDG_DATA_DIRS, LOCALE_ARCHIVE, and other non-NixOS FHS glue.
  # No nixGL lines — kitty/GPU apps are excluded on headless.
  targets.genericLinux.enable = true;
}
