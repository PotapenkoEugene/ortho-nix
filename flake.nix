{
  description = "Home Manager configuration of ortho (multi-host: Linux + macOS)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixgl = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nixvim,
    nixgl,
    nix-darwin,
    ...
  }: let
    # Local package overlay — same on all platforms.
    commonOverlay = final: prev: {
      playwright-cli = final.callPackage ./packages/playwright-cli/package.nix {};
      notebooklm-py = final.callPackage ./packages/notebooklm-py/package.nix {};
    };

    # Reusable HM module for macOS: nixvim + shared home config + ortho user identity.
    darwinHomeModule = {
      imports = [
        nixvim.homeModules.nixvim
        ./home.nix
        ./hosts/ortho-mac.nix
      ];
    };

    # Reusable darwin system module: overlays + HM submodule wiring + system config.
    # Exported as darwinModules.default — consumer imports this and gets everything.
    darwinSystemModule = {
      nixpkgs.config.allowUnfree = true;
      nixpkgs.overlays = [commonOverlay];
      imports = [
        home-manager.darwinModules.home-manager
        ./hosts/ortho-mac-system.nix
      ];
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.backupFileExtension = "backup";
      home-manager.users.ortho.imports = [darwinHomeModule];
    };

    # Linux: standalone home-manager with nixgl + genericLinux support.
    mkLinuxHome = {
      system,
      hostModule,
    }: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [commonOverlay];
        config.allowUnfree = true;
      };
    in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nixvim.homeModules.nixvim
          ./home.nix
          hostModule
        ];
        extraSpecialArgs = {inherit nixgl;};
      };
  in {
    # Overlay: exposes playwright-cli + notebooklm-py for external consumers.
    overlays.default = commonOverlay;

    # HM module: the full macOS home-manager config for user ortho.
    homeModules.darwin = darwinHomeModule;

    # Darwin module: the full nix-darwin system config (includes HM wiring).
    # Consumer usage:
    #   darwinConfigurations."hostname" = nix-darwin.lib.darwinSystem {
    #     modules = [ ortho-config.darwinModules.default { nix.enable = false; } ];
    #   };
    darwinModules.default = darwinSystemModule;

    homeConfigurations = {
      # x86_64-linux — standalone home-manager (activation: `home-manager switch --flake .#ortho`)
      "ortho" = mkLinuxHome {
        system = "x86_64-linux";
        hostModule = ./hosts/ortho-linux.nix;
      };
    };

    darwinConfigurations = {
      # aarch64-darwin — Mac Studio via nix-darwin (activation: `darwin-rebuild switch --flake .#ortho-mac`)
      "ortho-mac" = nix-darwin.lib.darwinSystem {
        modules = [self.darwinModules.default];
      };
    };
  };
}
