{lib, ...}: {
  options.ortho.headless = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Headless server host: no GUI/desktop integrations, no sops/age secrets, run under nix-portable. Gates desktop-only chunks across shared modules.";
  };
}
