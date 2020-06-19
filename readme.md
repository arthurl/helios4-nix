## Initial setup

This is written for this repo at tag `build-sd`

This sets up a machine with two disks using btrfs. This will clear anything
already on the disks!

Setting up the disks:

```sh
# New partition tables on sda and sdb
sgdisk --clear --new 0:0:0 /dev/sda
sgdisk --clear --new 0:0:0 /dev/sdb

# Set up btrfs
mkfs.btrfs -m raid1 -d raid1 /dev/sda1 /dev/sdb1

# Create a subvolume called nixos
mount /dev/sda1 /mnt/
btrfs subvolume create /mnt/nixos
umount /mnt/

# Mount this subvolume and create volumes for some other directories
mount -t btrfs -o subvol=nixos /dev/sda1 /mnt
btrfs subvolume create /mnt/var
btrfs subvolume create /mnt/home
btrfs subvolume create /mnt/tmp
btrfs subvolume create /mnt/boot
```

Installing NixOS:

```sh
# Set up your desired machine configuration
vim /mnt/etc/nixos/configuration.nix

# Initialize nixpkgs repo in /mnt/etc now

# Install!
NIX_PATH=nixpkgs=/mnt/etc/nixpkgs/ nixos-install
```

Oops, we forgot to make a boot partition
```sh
# Shrink the disk by 500MB
mount /dev/sda1 /mnt
btrfs filesystem resize -500m /mnt
umount /dev/sda1

# Delete the partition and make it again, 400MB smaller
sgdisk --delete 1 /dev/sda
sgdisk --new 0:0:-400M /dev/sda

# Create a boot partition
sgdisk --largest-new 0 /dev/sda
# This is the bootable attribute
sgdisk --attributes 2:set:2 /dev/sda
```

U-Boot's preference is to boot from the SD card, so to prevent this (hence
getting it to boot from the HDD) we should move `extlinux.conf` on the SD
card's boot partition.

```sh
mount /dev/mmcblk0p1 /mnt
mv /mnt/extlinux/extlinux.conf /mnt/extlinux/not-extlinux.conf/
umount /mnt
```
