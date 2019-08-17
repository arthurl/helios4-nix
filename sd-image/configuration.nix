# To build, use:
# nix-build nixos -I nixos-config=nixos/modules/installer/cd-dvd/sd-image-armv7l-multiplatform.nix -A config.system.build.sdImage
{ config, lib, pkgs, ... }:

let
  pkgsPath = import ./pkgs.nix;

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
    })
  ];

  extlinux-conf-builder =
    import (pkgsPath + "/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix") {
      inherit pkgs;
    };

in {
  imports = [
    (pkgsPath + "/nixos/modules/installer/cd-dvd/sd-image-armv7l-multiplatform.nix")
    ./helios4.nix
  ];

  environment.systemPackages = with pkgs; [
    vim
    tmux
    file
  ];

  services.openssh.enable = true;
  systemd.services.sshd.wantedBy = lib.mkOverride 40 [ "multi-user.target" ];

  security.sudo.enable = true;
  security.polkit.enable = false;
  security.pam.services.su.forwardXAuth = lib.mkOverride 40 false;

  nix.trustedUsers = [ "root" "@wheel" ];

  nixpkgs.overlays = overlays;

  users.mutableUsers = false;

  users.users.j = {
    isNormalUser = true;
    home = "/home/j";
    description = "Joe Hermaszewski";
    extraGroups = [ "wheel" ];
    hashedPassword = "$6$22Tois4OjFC$y3kfcuR7BBHVj8LnZNIfLyNhQOdVZkkTseXCNbiA95WS2JSXv4Zynmy8Ie9nCxNokgSL8cuO1Le0m4VHuzXXI.";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDFErWB61gZadEEFteZYWZm8QRwabpl4kDHXsm0/rsLqoyWJN5Y4zF4kowSGyf92LfJu9zNBs2viuT3vmsLfg6r4wkbVyujpEo3JLuV79r9K8LcM32wA52MvQYATEzxuamZPZCBT9fI/2M6bC9lz67RQ5IoENfjZVCstOegSmODmOvGUs6JjrB40slB+4YXCVFypYq3uTyejaBMtKdu1S4TWUP8WRy8cWYmCt1+a6ACV2yJcwnhSoU2+QKt14R4XZ4QBSk4hFgiw64Bb3WVQlfQjz3qA4j5Tc8P3PESKJcKW/+AsavN1I2FzdiX1CGo2OL7p9TcZjftoi5gpbmzRX05 j@riza"
    ];
  };

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
