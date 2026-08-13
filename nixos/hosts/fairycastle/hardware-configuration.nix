{ config, lib, ... }:

{
  boot.initrd.availableKernelModules = [ "nvme" ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  # A 75%-of-RAM logical zram device gives cold, compressible dev-server heaps
  # somewhere cheap to go without putting network I/O in the reclaim path.
  # There is intentionally no disk-backed swap on this host.
  zramSwap = {
    enable = true;
    memoryPercent = 75;
  };
  swapDevices = [];

  # Optimize reclaim for zram: prefer compressed anonymous pages over evicting
  # file cache, give kswapd more runway, and avoid disk-oriented readahead.
  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;
}
