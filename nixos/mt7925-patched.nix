# Out-of-tree build of the mt7925 WiFi driver with deadlock and mutex fixes.
# Builds only the mt7925 subdirectory (~1-2 min) instead of the full kernel.
#
# Fixes not yet upstream as of 6.18.x / 6.19 (targeting 6.20+):
#   - Sean Wang: fix ROC deadlock in mt7925_roc_abort_sync
#   - zbowling: mutex protection in reset/suspend/PM + NULL checks
#
# References:
#   https://github.com/zbowling/mt7925
#   https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301
#
# When these fixes land upstream, delete this file and both .patch files.
{ pkgs, lib, kernel }:

pkgs.stdenv.mkDerivation {
  pname = "mt7925-patched";
  inherit (kernel) src version postPatch nativeBuildInputs;

  patches = [
    ./mt7925-fix-roc-deadlock.patch
    ./mt7925-mutex-and-null-fixes.patch
  ];

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
