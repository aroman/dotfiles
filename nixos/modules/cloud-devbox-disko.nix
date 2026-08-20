{ cloudDevboxDisk, lib, ... }:

{
  assertions = [
    {
      assertion = cloudDevboxDisk != null;
      message = "mkCloudDevbox: cloudDevboxDisk is required";
    }
  ];

  disko.devices.disk.main = {
    type = "disk";
    # Use the stable NVMe EUI. GCE's google-* alias exists in the guest OS but
    # is absent from nixos-anywhere's generic kexec image.
    device = lib.mkIf (cloudDevboxDisk != null) cloudDevboxDisk;
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          name = "ESP";
          start = "1MiB";
          end = "1GiB";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };

        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            extraArgs = [ "-L" "nixos" ];
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
