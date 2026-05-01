{
  pkgs,
  lib,
  ...
}: {
  # Set platform so nix-darwin.lib.darwinSystem doesn't require a `system` arg.
  nixpkgs.hostPlatform = lib.mkDefault "aarch64-darwin";

  # Declare the primary user so home-manager knows where to install files.
  users.users.ortho = {
    name = "ortho";
    home = "/Users/ortho";
  };

  # Enable flakes for `darwin-rebuild` itself.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # nix-darwin state version — separate from home-manager's stateVersion.
  # 6 is current as of nix-darwin 25.05; bump only on instructed migrations.
  system.stateVersion = 6;

  # Register bash in /etc/shells (required when using bash as default shell).
  programs.bash.enable = true;
}
