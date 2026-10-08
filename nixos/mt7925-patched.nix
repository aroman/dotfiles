# Out-of-tree build of the mt7925 WiFi driver with mutex/NULL fixes.
# Builds only the mt7925 subdirectory (~1-2 min) instead of the full kernel.
#
# Sean Wang's ROC deadlock fix landed upstream in kernel 7.0.10 and was
# dropped here on 2026-05-25. The remaining patch:
#   - zbowling: mutex protection in reset/suspend/PM + NULL checks
#
# Rebased onto 7.2.9 on 2026-10-07, dropping the reset-path NULL check that
# is now upstream. Reject fuzzy application so kernel updates cannot silently
# place hunks using stale context. Also check a new source tree with:
#
#   git -C <kernel-src> apply --check nixos/mt7925-mutex-and-null-fixes.patch
#
# and regenerate against the new tree if it complains. See the patch header.
#
# References:
#   https://github.com/zbowling/mt7925
#   https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301
#
# When the remaining patch lands upstream, delete this file, the .patch,
# and the boot.extraModulePackages block in hosts/moonbinder/default.nix.
{ pkgs, lib, kernel }:

pkgs.stdenv.mkDerivation {
  pname = "mt7925-patched";
  inherit (kernel) src version postPatch nativeBuildInputs;

  patches = [
    ./mt7925-mutex-and-null-fixes.patch
  ];
  patchFlags = [ "-p1" "--fuzz=0" ];

  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;

  modulePath = "drivers/net/wireless/mediatek/mt76/mt7925";

  buildPhase = ''
    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build

    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config        .
    cp $kernel_dev/vmlinux           .

    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules
  '';

  # Install to updates/ so depmod prioritizes our patched modules over
  # the stock kernel/ ones. This avoids collisions in aggregateModules.
  installPhase = ''
    make \
      INSTALL_MOD_PATH="$out" \
      INSTALL_MOD_DIR="updates" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M="$modulePath" \
      modules_install
  '';

  meta = {
    description = "Patched MT7925 WiFi driver with deadlock and mutex fixes";
    license = lib.licenses.gpl2Only;
  };
}
