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

    # Niri: vanilla via niri-flake (`pkgs.niri-unstable`).  As of v26.04,
    # blur landed in upstream main, so the pure-blur fork override we used
    # to carry is no longer needed.  niri-flake auto-bumps niri-unstable
    # ~daily and pushes binaries to niri.cachix.org.
    #
    # ── Parked: cursor-zoom variant ──
    # Cursor-zoom (PR #3246) hasn't merged into niri main yet.  When it
    # does, drop this block; until then, re-enable it by:
    #
    #   1. Uncommenting the `niri-blur` input below.
    #   2. Adding `inputs.niri-unstable.follows = "niri-blur";` to the
    #      niri input below.
    #   3. Uncommenting the matching blur-patch overlay further down in
    #      `mkSystem`.
    #   4. Saving the companion patch to nixos/niri-blur-zoom.patch.
    #      Source: "The rest of the blur PR" by YaLTeR (niri's maintainer),
    #      commit 1ba37d7c from 2026-02-21.  Download:
    #        https://github.com/niri-wm/niri/pull/3246#issuecomment-4194759585
    #
    # Pin is c6d807427 — the commit that was HEAD when Atan-D-RP4 posted
    # the blur-companion patch attachment on 2026-04-06.  Later rebases of
    # that branch force-pushed newer history which partially-merged the
    # blur PR's rendering half but not its config structs, breaking patch
    # compatibility and leaving blur unconfigurable.
    #
    # Caveat: the patch's rendering-path hunks may also conflict with
    # v26.04's blur pipeline (zoom-then-blur vs. blur-then-zoom), so on
    # its own it can produce a broken build.  Keep parked until upstream
    # reconciliation.
    # niri-blur = {
    #   url = "github:Atan-D-RP4/niri/c6d807427";
    #   flake = false;
    # };

    niri = {
      url = "github:sodiboo/niri-flake";
    };

    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned to an explicit release tag so each bump is a deliberate edit
    # with readable changelog context (vs. tracking the default branch).
    # When bumping, verify the new tag is present in vicinae.cachix.org
    # first — upstream's release pipeline only pushes some tags to cache,
    # and a miss means a 5–15 min Qt/C++ from-source rebuild.
    # Check: curl -sI https://vicinae.cachix.org/$(nix eval --raw \
    #   .#nixosConfigurations.moonbinder.config.home-manager.users.aroman.services.vicinae.package \
    #   | xargs basename | cut -d- -f1).narinfo
    vicinae.url = "github:vicinaehq/vicinae/v0.20.11";

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
          {
            nixpkgs.overlays = [
              niri.overlays.niri
              # Uncomment this overlay ONLY when re-enabling the parked
              # cursor-zoom niri-blur input above — it applies the blur
              # PR patch on top of the cursor-zoom branch.  The patch
              # file is not checked in; fetch it per the instructions in
              # the niri-blur input comment and save to
              # nixos/niri-blur-zoom.patch before baking.
              # (final: prev: {
              #   niri-unstable = prev.niri-unstable.overrideAttrs (old:
              #     let
              #       patchedSrc = final.applyPatches {
              #         name = "niri-blur-zoom-src";
              #         src = old.src;
              #         patches = [ ./niri-blur-zoom.patch ];
              #       };
              #     in {
              #       src = patchedSrc;
              #       cargoDeps = final.rustPlatform.importCargoLock {
              #         lockFile = "${patchedSrc}/Cargo.lock";
              #         allowBuiltinFetchGit = true;
              #       };
              #     });
              # })
            ];
          }
          ./noctalia.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.aroman = import ./hosts/${hostname}/home.nix;
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./modules/common.nix
          ./modules/restic.nix
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

      wizardtower = mkSystem {
        hostname = "wizardtower";
      };
    };
  };
}
