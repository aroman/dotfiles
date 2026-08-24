{
  description = "Avi's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # v5 is a ground-up C++ rewrite of the QML/Quickshell v4 line; the repo was
    # renamed noctalia-shell -> noctalia and the binary noctalia-shell ->
    # noctalia.  The noctalia-qs input is gone with it — nothing pulls
    # Quickshell any more.  Still a beta: pin an exact tag, don't track a branch.
    #
    # This input is used for its home-manager module ONLY, not its package.
    # Building nix/package.nix here would be a from-source C++ build; nixpkgs
    # ships the identical 5.0.0-beta.7 prebuilt on cache.nixos.org, so
    # noctalia.nix overrides programs.noctalia.package with `pkgs.noctalia`.
    # Keep this tag and the nixpkgs `version` in lockstep when bumping — the
    # module and the package are versioned together upstream.
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.0.0-beta.7";
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
  };

  outputs = inputs@{ self, nixpkgs, home-manager, nixos-hardware, niri, disko, ... }:
  let
    reservedHostArgumentNames = [
      "inputs"
      "desktop"
      "username"
      "cloudDevbox"
      "cloudDevboxDisk"
      "gceBootDiskId"
      "resticRepository"
      "cloudDevboxGit"
    ];
    extraSpecialArgsAreSafe = args:
      builtins.all
        (name: !(builtins.hasAttr name args))
        reservedHostArgumentNames;

    # The raw constructor is deliberately private. Host-kind wrappers below
    # close over identity-sensitive flags so callers cannot accidentally build
    # a desktop for another user or turn cloud hardening off.
    mkHost = {
      hostname,
      username,
      desktop,
      cloudDevbox,
      resticRepository,
      cloudDevboxGit,
      system ? "x86_64-linux",
      cloudDevboxDisk ? null,
      extraModules ? [],
      extraSpecialArgs ? {},
    }:
      assert nixpkgs.lib.assertMsg (desktop != cloudDevbox)
        "mkHost: exactly one of desktop or cloudDevbox must be enabled";
      assert nixpkgs.lib.assertMsg (!desktop || username == "aroman")
        "mkHost: desktop configurations are intentionally fixed to aroman";
      assert nixpkgs.lib.assertMsg (cloudDevbox == (cloudDevboxDisk != null))
        "mkHost: cloudDevboxDisk must be set exactly when cloudDevbox is enabled";
      assert nixpkgs.lib.assertMsg
        (extraSpecialArgsAreSafe extraSpecialArgs)
        "mkHost: extraSpecialArgs cannot override reserved host arguments";
      nixpkgs.lib.nixosSystem {
        inherit system;
        # Structural arguments are right-biased as defense in depth; the
        # assertion above also rejects attempts to smuggle one through.
        specialArgs = extraSpecialArgs // {
          inherit
            inputs
            desktop
            username
            cloudDevbox
            cloudDevboxDisk
            resticRepository
            cloudDevboxGit
            ;
        };
        modules = (nixpkgs.lib.optionals desktop [
          niri.nixosModules.niri
          {
            nixpkgs.overlays = [
              niri.overlays.niri
              # nixpkgs removed `libdisplay-info_0_2` on 2026-08-04 ("unused
              # in Nixpkgs"), leaving a throwing alias behind.  niri-flake's
              # package still asks for it *and* asserts `version == "0.2.0"`,
              # so evaluating `programs.niri.package` hits the throw.
              #
              # niri's libdisplay-info-sys 0.3.0 accepts any C library in
              # `>= 0.1.0, < 0.4.0`, so 0.3 would do — but the assert only
              # takes 0.2.0, and plain `libdisplay-info` is 0.4.0, out of
              # range.  So reinstate 0.2.0 from the current recipe; it's a
              # few seconds of meson.
              #
              # Drop this once niri-flake merges sodiboo/niri-flake#1853
              # (picks the C library from each niri's Cargo.lock) and the
              # niri input is bumped past it.
              (final: prev: {
                libdisplay-info_0_2 = prev.libdisplay-info.overrideAttrs {
                  version = "0.2.0";
                  src = prev.fetchFromGitLab {
                    domain = "gitlab.freedesktop.org";
                    owner = "emersion";
                    repo = "libdisplay-info";
                    tag = "0.2.0";
                    hash = "sha256-6xmWBrPHghjok43eIDGeshpUEQTuwWLXNHg7CnBUt3Q=";
                  };
                };
              })
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
            ];
          }
          ./noctalia.nix
        ]) ++ [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.${username} = import ./hosts/${hostname}/home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs desktop username cloudDevbox cloudDevboxGit;
            };
          }
          ./modules/options.nix
          ./modules/common.nix
        ] ++ (nixpkgs.lib.optional desktop ./modules/desktop.nix)
        ++ (nixpkgs.lib.optionals cloudDevbox [
          disko.nixosModules.disko
          ./modules/cloud-devbox.nix
          ./modules/cloud-devbox-disko.nix
        ])
        ++ (nixpkgs.lib.optional (resticRepository != null) ./modules/restic.nix)
        ++ [
          ./hosts/${hostname}/default.nix
          ./hosts/${hostname}/hardware-configuration.nix
        ] ++ extraModules;
      };
    mkDesktopSystem = {
      hostname,
      system ? "x86_64-linux",
      extraModules ? [],
      extraSpecialArgs ? {},
    }:
      mkHost {
        inherit hostname system extraModules extraSpecialArgs;
        username = "aroman";
        desktop = true;
        cloudDevbox = false;
        cloudDevboxDisk = null;
        cloudDevboxGit = null;
        resticRepository = "b2:aroman-backups";
      };

    mkCloudDevbox = {
      hostname,
      username,
      cloudDevboxDisk,
      gceBootDiskId,
      resticRepository,
      gitUserName,
      gitUserEmail,
      gitSigningKey,
      githubIdentityFile,
      system ? "x86_64-linux",
      extraModules ? [],
      extraSpecialArgs ? {},
    }:
      assert nixpkgs.lib.assertMsg
        (builtins.match "[0-9]+" gceBootDiskId != null)
        "mkCloudDevbox: gceBootDiskId must be a decimal GCE disk ID";
      mkHost {
        inherit
          hostname
          username
          system
          cloudDevboxDisk
          resticRepository
          extraModules
          extraSpecialArgs
          ;
        desktop = false;
        cloudDevbox = true;
        cloudDevboxGit = {
          inherit gitUserName gitUserEmail gitSigningKey githubIdentityFile;
        };
      };

    cloudDevboxHostnames = builtins.filter
      (hostname:
        builtins.pathExists (./hosts + "/${hostname}/cloud-devbox.nix"))
      (builtins.attrNames (builtins.readDir ./hosts));
    cloudDevboxSystems = builtins.listToAttrs (map
      (hostname:
        let
          hostArgs = import (./hosts + "/${hostname}/cloud-devbox.nix");
        in {
          name = hostname;
          value = assert nixpkgs.lib.assertMsg (hostArgs.hostname == hostname)
            "hosts/${hostname}/cloud-devbox.nix must declare hostname = \"${hostname}\"";
            mkCloudDevbox hostArgs;
        })
      cloudDevboxHostnames);

    cloudDevboxInterfaceCheck =
      let
        testArgs = {
          hostname = "fairycastle";
          username = "newdev";
          cloudDevboxDisk = "/dev/disk/by-id/test-cloud-devbox";
          gceBootDiskId = "123456789";
          resticRepository = "b2:test-cloud-devbox";
          gitUserName = "New Developer";
          gitUserEmail = "newdev@example.com";
          gitSigningKey = "~/.ssh/newdev.pub";
          githubIdentityFile = "~/.ssh/newdev";
        };
        testConfig = (mkCloudDevbox testArgs).config;
        noBackupConfig = (mkCloudDevbox (testArgs // {
          resticRepository = null;
        })).config;
        testHome = testConfig.home-manager.users.newdev;
        cloudArgs = builtins.functionArgs mkCloudDevbox;
      in
        assert testConfig.users.users ? newdev;
        assert !(testConfig.users.users ? aroman);
        assert testConfig.home-manager.users ? newdev;
        assert !(testConfig.home-manager.users ? aroman);
        assert testConfig.services.restic.backups.b2.repository == "b2:test-cloud-devbox";
        assert noBackupConfig.services.restic.backups == {};
        assert !(builtins.hasAttr "restic-backups-b2" noBackupConfig.systemd.services);
        assert testConfig.users.mutableUsers == false;
        assert testConfig.systemd.services.google-startup-scripts.wantedBy == [];
        assert testConfig.systemd.services.google-shutdown-scripts.wantedBy == [];
        assert nixpkgs.lib.hasInfix
          "accounts_daemon = false"
          testConfig.environment.etc."default/instance_configs.cfg".text;
        assert nixpkgs.lib.hasInfix "name = New Developer" testHome.home.file.".gitconfig.local".text;
        assert nixpkgs.lib.hasInfix "email = newdev@example.com" testHome.home.file.".gitconfig.local".text;
        assert nixpkgs.lib.hasInfix "IdentityFile ~/.ssh/newdev" testHome.home.file.".ssh/config.local".text;
        assert !(cloudArgs ? desktop);
        assert !(cloudArgs ? cloudDevbox);
        assert cloudArgs.username == false;
        assert cloudArgs.gceBootDiskId == false;
        assert cloudArgs.resticRepository == false;
        assert !(extraSpecialArgsAreSafe { username = "otherdev"; });
        nixpkgs.legacyPackages.x86_64-linux.runCommand
          "cloud-devbox-interface-check"
          { }
          "touch $out";

    staticSystems = {
      moonbinder = mkDesktopSystem {
        hostname = "moonbinder";
        extraModules = [
          nixos-hardware.nixosModules.framework-16-amd-ai-300-series
        ];
      };

      wizardtower = mkDesktopSystem {
        hostname = "wizardtower";
      };
    };
    cloudDevboxStaticCollisions = builtins.attrNames
      (builtins.intersectAttrs staticSystems cloudDevboxSystems);
  in {
    packages.x86_64-linux.nixos-anywhere-host-key-pinned =
      nixpkgs.legacyPackages.x86_64-linux.callPackage
        ./nixos-anywhere-host-key-pinned.nix
        { };

    checks.x86_64-linux.cloud-devbox-interface = cloudDevboxInterfaceCheck;

    nixosConfigurations =
      assert nixpkgs.lib.assertMsg (cloudDevboxStaticCollisions == [])
        "cloud devboxes cannot shadow static hosts: ${builtins.concatStringsSep ", " cloudDevboxStaticCollisions}";
      staticSystems // cloudDevboxSystems;
  };
}
