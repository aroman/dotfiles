{ pkgs }:

let
  # Pin the installer because the patch below deliberately matches its SSH
  # argument initialization exactly.  Updating the revision must also update
  # the hash and review whether the patch is still necessary.
  source = builtins.fetchTree {
    type = "github";
    owner = "nix-community";
    repo = "nixos-anywhere";
    rev = "ad8fa24e11eef167fd72d49fafefa3f840312d71";
    narHash = "sha256-aKf1k2hvYgaxP9oxDPRiv9npEJLODC9eKxk7nR69lzQ=";
  };
  upstream = pkgs.callPackage "${source}/src" { };
in
upstream.overrideAttrs (old: {
  pname = "nixos-anywhere-host-key-pinned";

  # nixos-anywhere 1.13.0 puts these unsafe values before --ssh-option.
  # OpenSSH keeps the first value for scalar options, so callers cannot
  # override them.  Remove only those defaults; the provisioner supplies a
  # pinned known_hosts file and StrictHostKeyChecking=yes.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace src/nixos-anywhere.sh \
      --replace-fail \
        'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere" "-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no")' \
        'declare -a sshArgs=("-o" "IdentitiesOnly=yes" "-i" "$tempDir/nixos-anywhere")'
  '';
})
