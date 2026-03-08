{
  description = "Avi's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Pinned nixpkgs for kernel 6.17.13 — last commit before 6.17 was removed.
    # Workaround for MES firmware hang in 6.18+/6.19+ on Strix Point (Radeon 860M).
    # Remove this once the amdgpu MES fix lands upstream and reaches nixpkgs.
    # Tracker: https://community.frame.work/t/attn-critical-bugs-in-amdgpu-driver-included-with-kernel-6-18-x-6-19-x/79221
    nixpkgs-kernel.url = "github:NixOS/nixpkgs/158fc4d1067c7e825fc9803a981e3acc2f4845fa";

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

  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixos-hardware, niri, ... }: {
    nixosConfigurations.wizardtower = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = {
        inherit inputs;
        pkgs-kernel = import inputs.nixpkgs-kernel { system = "x86_64-linux"; };
      };
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
