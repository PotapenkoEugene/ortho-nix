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
    nixpkgs,
    home-manager,
    nixvim,
    nixgl,
    nix-darwin,
    ...
  }: let
    # Local package overlays — same on all platforms.
    commonOverlays = [
      (final: prev: {
        playwright-cli = final.callPackage ./packages/playwright-cli/package.nix {};
        notebooklm-py = final.callPackage ./packages/notebooklm-py/package.nix {};
      })
    ];

    # Linux: standalone home-manager with nixgl + genericLinux support.
    mkLinuxHome = {
      system,
      hostModule,
    }: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = commonOverlays;
        config.allowUnfree = true;
      };
    in
      home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          nixvim.homeManagerModules.nixvim
          ./home.nix
          hostModule
        ];
        extraSpecialArgs = {inherit nixgl;};
      };

    # Darwin: nix-darwin with home-manager loaded as a submodule.
    mkDarwinSystem = {
      system,
      systemModule,
      hmHostModule,
    }:
      nix-darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {inherit nixvim home-manager;};
        modules = [
          {
            nixpkgs.config.allowUnfree = true;
            nixpkgs.overlays = commonOverlays;
          }
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.ortho.imports = [
              nixvim.homeManagerModules.nixvim
              ./home.nix
              hmHostModule
            ];
          }
          systemModule
        ];
      };
  in {
    homeConfigurations = {
      # x86_64-linux — standalone home-manager (unchanged activation: `ortho`)
      "ortho" = mkLinuxHome {
        system = "x86_64-linux";
        hostModule = ./hosts/ortho-linux.nix;
      };
    };

    darwinConfigurations = {
      # aarch64-darwin — Apple Silicon Mac Studio via nix-darwin
      "ortho-mac" = mkDarwinSystem {
        system = "aarch64-darwin";
        systemModule = ./hosts/ortho-mac-system.nix;
        hmHostModule = ./hosts/ortho-mac.nix;
      };
    };
  };
}
