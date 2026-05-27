{
  description = "Avi's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell/v4.7.7";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Niri: cursor-zoom variant via Atan-D-RP4's feat/cursor-zoom branch
    # (PR #3246).  Branch is rebased on niri main, so blur (which landed in
    # v26.04) is included.  No companion patch needed at this pin.
    #
    # Pin is 601fcdc1 — HEAD of feat/cursor-zoom on 2026-05-12.  The branch
    # is force-pushed regularly during development; bump this commit when
    # updating.  The API is unstable and the author has stated they plan a
    # from-scratch rewrite with cleaner history before YaLTeR review, so
    # config syntax may change.
    #
    # To drop back to vanilla niri-unstable: remove niri-cursor-zoom input,
    # remove the `inputs.niri-unstable.follows` line on the niri input.
    niri-cursor-zoom = {
      url = "github:Atan-D-RP4/niri/601fcdc110";
      flake = false;
    };

    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.niri-unstable.follows = "niri-cursor-zoom";
    };

    voxtype = {
      url = "github:peteonrails/voxtype";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tracks vicinae's default branch; the flake lock is the source of truth.
    # Bump with `nix flake update vicinae`. Upstream's release pipeline only
    # pushes tagged commits to vicinae.cachix.org, so an update that lands
    # on a between-release commit will force a 5–15 min Qt/C++ source build —
    # if that happens, re-run after a fresh tag is cut, or temporarily pin
    # a tag via `?ref=vX.Y.Z`.
    vicinae.url = "github:vicinaehq/vicinae";

    # Sunshine 2026.516.143833 — pinned to NixOS/nixpkgs#521906 (Qubasa's
    # bump branch). Carries security fix GHSA-ph75-mgxh-mv57 + KMS capture
    # fixes (potentially relevant to the "Couldn't find monitor [0]" wedge).
    # Drop this input once the PR merges and nixpkgs-unstable catches up.
    # No `inputs.nixpkgs.follows` — the whole point is a different revision.
    nixpkgs-sunshine.url = "github:Qubasa/nixpkgs/9672041e168ea7e431074220bb71920ddbe4106d";

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
              # tuigreet hardcodes "Authenticate into {hostname}" as the
              # main prompt title via a bundled fluent translation. Patch
              # the en-US locale to drop the prefix, leaving just the
              # hostname.
              (final: prev: {
                tuigreet = prev.tuigreet.overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    substituteInPlace contrib/locales/en-US/tuigreet.ftl \
                      --replace-fail \
                        'title_authenticate = Authenticate into {$hostname}' \
                        'title_authenticate = {$hostname}'
                  '';
                });
              })
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
          ./modules/options.nix
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
