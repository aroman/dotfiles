{
  description = "Avi's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Ghostty tip, prebuilt by upstream CI on ghostty.cachix.org.
    # Keep its own nixpkgs pin so the package matches upstream's cache.
    # Update with `nix flake update ghostty --flake ./nixos`.
    ghostty.url = "github:ghostty-org/ghostty";

    spotifast = {
      url = "github:crmne/spotifast";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Kernel-only package set for moonbinder: Linux 7.2.9 includes the TTM
    # hibernation use-after-free fix. Keep the rest of the system on its
    # existing nixpkgs lock; see hosts/moonbinder/default.nix for the iwd fix.
    nixpkgs-kernel.url = "github:NixOS/nixpkgs/151fa4e8ddfdd8dd25d945ad94ed54a13de9f6e4";

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
    # Quickshell any more.  Pin an exact tag, don't track a branch.
    #
    # This input is used for its home-manager module ONLY, not its package.
    # Building nix/package.nix here would be a from-source C++ build; nixpkgs
    # ships the identical version prebuilt on cache.nixos.org, so noctalia.nix
    # overlays pkgs.noctalia from `nixpkgs-noctalia` below.  Keep this tag and
    # that nixpkgs' `version` in lockstep when bumping — the module and the
    # package are versioned together upstream.
    #
    # To bump noctalia without moving the rest of the system:
    #   1. set the tag here to the version nixos-unstable's noctalia has
    #   2. nix flake update noctalia nixpkgs-noctalia --flake .../nixos
    noctalia = {
      url = "github:noctalia-dev/noctalia/v5.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Separate nixpkgs used ONLY for pkgs.noctalia (overlaid in noctalia.nix),
    # so the shell can move ahead of the system nixpkgs.  Prebuilt on
    # cache.nixos.org; costs a second copy of noctalia's runtime libs.
    nixpkgs-noctalia.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Vanilla niri-unstable from the maintained niri-flake packaging fork.
    # Keep its upstream source pin intact to use the fork's binary cache
    # (enabled by its NixOS module), rather than compiling a custom rev.
    # Update with `nix flake update niri --flake ./nixos`.
    niri.url = "github:epireyn/niri-flake";

    # Only the home-manager module comes from here; the binary is
    # hosts/moonbinder/voxtype-bin.nix. Keep this tag at the same version.
    voxtype = {
      url = "github:peteonrails/voxtype/v1.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Tracks vicinae's default branch; the flake lock is the source of truth.
    # Bump with `nix flake update vicinae`. Upstream's release pipeline only
    # pushes tagged commits to vicinae.cachix.org, so an update that lands
    # on a between-release commit will force a 5–15 min Qt/C++ source build —
    # if that happens, re-run after a fresh tag is cut, or temporarily pin
    # a tag via `?ref=vX.Y.Z`.
    vicinae.url = "github:vicinaehq/vicinae";

    # iPhone continuity: clipboard, files, SMS/iMessage, notifications.
    # Used for its NixOS module (hosts/moonbinder); the package is a C++
    # source build (not on any cache), small enough not to matter.
    tether = {
      url = "github:zackb/tether";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Desktop: Anthropic's official Linux .deb, repackaged for Nix.
    # Their launcher script (--doctor, CLAUDE_USE_WAYLAND) is deb/rpm-only;
    # the Nix build runs Electron directly, which picks Wayland on niri by
    # itself. Only the overlay is used (hosts/moonbinder), built against our
    # nixpkgs. Upstream auto-bumps the .deb; pull with
    # `nix flake update claude-desktop`.
    claude-desktop = {
      url = "github:aaddrick/claude-desktop-debian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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
              # Use the exact package built by the flake's CI. Rebuilding it
              # against our system nixpkgs produces a different store path
              # that isn't in the cache, even with the same niri source pin.
              (final: prev: {
                niri-unstable = inputs.niri.packages.${prev.stdenv.hostPlatform.system}.niri-unstable;
              })
              # tuigreet hardcodes "Authenticate into {hostname}" as the
              # main prompt title via a bundled fluent translation. Patch
              # the en-US locale to drop the prefix, leaving just the
              # hostname.
              #
              # 0.11.0 moved the locales out of contrib/ and into their own
              # crate, renaming the file in the process:
              #   contrib/locales/en-US/tuigreet.ftl
              #   -> crates/tuigreet-locales/locales/en-US/tuigreet-locales.ftl
              # The old path silently vanished, and because substitute()
              # errors on a missing file this broke the build outright on
              # every host rather than degrading quietly. Keep --replace-fail
              # so a future string change fails loudly here too.
              (final: prev: {
                tuigreet = prev.tuigreet.overrideAttrs (old: {
                  postPatch = (old.postPatch or "") + ''
                    substituteInPlace crates/tuigreet-locales/locales/en-US/tuigreet-locales.ftl \
                      --replace-fail \
                        'title_authenticate = Authenticate into {$hostname}' \
                        'title_authenticate = {$hostname}'
                  '';
                  # show_wrapped_greet asserts on the exact title string the
                  # patch above rewrites, so it necessarily fails once the
                  # prefix is gone. Skip that one case rather than turning
                  # off doCheck — the other 90 tests still run and still
                  # guard the package.
                  checkFlags = (old.checkFlags or [ ]) ++ [
                    "--skip=integration::display::show_wrapped_greet"
                  ];
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
