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
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      # inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixos-hardware, niri, ... }: {
    nixosConfigurations.wizardtower = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        nixos-hardware.nixosModules.framework-16-amd-ai-300-series
        niri.nixosModules.niri
        { nixpkgs.overlays = [ niri.overlays.niri ]; }
        ./noctalia.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.users.aroman = import ./home.nix;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
        ./configuration.nix
        ./hardware-configuration.nix
      ];
    };
  };
}
