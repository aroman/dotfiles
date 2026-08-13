{ ... }:

{
  disko.devices.disk.main = {
    type = "disk";
    # Debian's GCE guest rules also expose this disk as
    # /dev/disk/by-id/google-devbox-fairycastle. The generic nixos-anywhere
    # kexec image does not ship that alias, but does expose the disk's stable
    # NVMe EUI, so use the identity that exists in both environments.
    device = "/dev/disk/by-id/nvme-eui.6cdf21c8b4d3addc0000000000000000";
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
