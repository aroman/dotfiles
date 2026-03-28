{
  description = "Avi's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # FIXME: using dniku's fork to fix FW16 phantom Headphones/Mic defaults.
    # Upstream alsa-ucm-conf is fixed (>=v1.2.15.3), but nixos-hardware hasn't picked it up.
    # Check periodically:
    #   - nixos-hardware PRs: https://github.com/NixOS/nixos-hardware/pulls?q=framework+16+audio
    #   - alsa-ucm-conf version in nixpkgs: nix eval nixpkgs#alsa-ucm-conf.version
    #   - upstream fix: https://github.com/alsa-project/alsa-ucm-conf/issues/673
    # Once fixed, switch back to: github:NixOS/nixos-hardware/master
    nixos-hardware.url = "github:dniku/nixos-hardware/fw16-ai300-upstream-ucm-fix";

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell/v4.7.1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Using niri blur branch (PR #3483). Remove once blur is merged to main.
    niri-blur = {
      url = "github:niri-wm/niri/wip/branch";
      flake = false;
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.niri-unstable.follows = "niri-blur";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    vicinae.url = "github:vicinaehq/vicinae";

    lan-mouse = {
      url = "github:feschber/lan-mouse";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixos-hardware, niri, ... }:
  let
    mkSystem = { hostname, system ? "x86_64-linux", extraModules ? [], extraSpecialArgs ? {} }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs;
        } // extraSpecialArgs;
        modules = [
          niri.nixosModules.niri
          { nixpkgs.overlays = [ niri.overlays.niri ]; }
          ./noctalia.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.aroman = import ./hosts/${hostname}/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./modules/common.nix
          ./hosts/${hostname}/default.nix
          ./hosts/${hostname}/hardware-configuration.nix
        ] ++ extraModules;
      };
  in {
    nixosConfigurations = {
      moonbinder = mkSystem {
        hostname = "moonbinder";
        extraModules = [
          nixos-hardware.nixosModules.framework-16-amd-ai-300-series
        ];
      };
    };
  };
}
