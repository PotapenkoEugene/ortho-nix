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
    shell = pkgs.bash;
  };

  # Determinate Nix manages the installation — disable nix-darwin's conflicting management.
  nix.enable = false;

  # nix-darwin state version — separate from home-manager's stateVersion.
  # 6 is current as of nix-darwin 25.05; bump only on instructed migrations.
  system.stateVersion = 6;

  # Register bash in /etc/shells (required when using bash as default shell).
  programs.bash.enable = true;

  # Allow ortho to run darwin-rebuild without password (required for remote SSH automation).
  security.sudo.extraConfig = ''
    ortho ALL=(ALL) NOPASSWD: /run/current-system/sw/bin/darwin-rebuild
  '';
}
