# To build, use:
# nix-build nixos -I nixos-config=nixos/modules/installer/cd-dvd/sd-image-armv7l-multiplatform.nix -A config.system.build.sdImage
{ config, lib, pkgs, modulesPath  , ... }:

let
  overlays = [
    (self: super: {
      # Seems to have some problem testing on
      # the build server. Sad that we need libjpeg at all...
      libjpeg = pkgs.lib.overrideDerivation super.libjpeg_turbo (attrs: {
        checkPhase = ":";
      });
      dbus = super.dbus.override {
        x11Support = false;
      };
      rng-tools = super.rng-tools.override {
        withPkcs11 = false;
      };
    })
  ];

  extlinux-conf-builder =
    import (modulesPath + "/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix") {
      inherit pkgs;
    };

in {
  imports = [
    ../helios4.nix
    (modulesPath + "/installer/cd-dvd/sd-image-armv7l-multiplatform.nix")
    (modulesPath + "/profiles/minimal.nix")
  ];

  environment.systemPackages = with pkgs; [
    vim
    tmux
    file
  ];

  services.openssh.enable = true;
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  security.sudo.enable = true;

  # Making things small
  security.polkit.enable = false;
  security.pam.services.su.forwardXAuth = lib.mkOverride 40 false;
  fonts.fontconfig.enable = false;

  nix.trustedUsers = [ "root" "@wheel" ];

  nixpkgs.overlays = overlays;

  users.mutableUsers = false;

  users.users.guest = {
    isNormalUser = true;
    home = "/home/guest";
    description = "A User";
    extraGroups = [ "wheel" ];
    password = "a";
  };

  boot.supportedFilesystems = lib.mkForce [ "btrfs" "reiserfs" "vfat" "f2fs" "xfs" "ntfs" "cifs" "ext4" "vfat" ];

  boot.postBootCommands = ''
  # On the first boot do some maintenance tasks
  if [ -f /nix-path-registration ]; then
    # Figure out device names for the boot device and root filesystem.
    rootPart=$(readlink -f /dev/disk/by-label/NIXOS_SD)
    bootDevice=$(lsblk -npo PKNAME $rootPart)

    # Resize the root partition and the filesystem to fit the disk
    echo ",+," | sfdisk -N$(echo $rootPart | grep -Eo '[0-9]+$') --no-reread $bootDevice
    ${pkgs.parted}/bin/partprobe
    ${pkgs.e2fsprogs}/bin/resize2fs $rootPart

    # Register the contents of the initial Nix store
    ${config.nix.package.out}/bin/nix-store --load-db < /nix-path-registration

    # nixos-rebuild also requires a "system" profile and an /etc/NIXOS tag.
    touch /etc/NIXOS
    ${config.nix.package.out}/bin/nix-env -p /nix/var/nix/profiles/system --set /run/current-system

    # Prevents this from running on later boots.
    rm -f /nix-path-registration
  fi
'';

}
