let pkgsPath = import ./pkgs.nix;
    pkgs = import pkgsPath {};
    system = "armv7l-linux";
    nixos = import (pkgsPath + "/nixos");
    configuration = ./configuration.nix;
    config = (nixos { inherit system configuration; }).config;

    # All store paths that will be present on the root partition
    storePaths = [ config.system.build.toplevel ];

    # The ext4 root partition
    rootfsImage = import (pkgsPath + "/nixos/lib/make-ext4-fs.nix") {
      inherit pkgs storePaths;
      volumeLabel = "NIXOS_SD";
      inherit (pkgs) e2fsprogs libfaketime perl lkl;
    };

    # Packages we want to cross compile to arm
    crossPkgs = import pkgsPath {
      crossSystem = {
        system = "armv7l-linux";
      };
    };

    # u-boot
    #
    # - Support for BTRFS turned on in the config
    # - SCSI support for large devices turned on in a patch file.
    u-boot = crossPkgs.buildUBoot rec {
        defconfig = "helios4_defconfig";
        extraMeta.platforms = [ "armv7l-linux" ];
        filesToInstall = [ "u-boot-spl.kwb" ];
        src = pkgs.fetchFromGitHub {
          owner = "helios-4";
          # repo = "u-boot";
          repo = "u-boot-marvell";
          rev = "3221f0f219f343a38b5f84dc839cc825a6f863f0";
          sha256 = "1fgld3fb0xf1l9kf534qsvddya8bbcwqz475x8gcxpvz16b1kwpa";
        };
        postConfigure = ''
          setConfig() {
            sed -i "/^CONFIG_$1[ =]/d" .config
            echo "CONFIG_$1=$2" >> .config
          }

          setConfig FS_BTRFS y
          setConfig CMD_BTRFS y
          patch -p1 < ${./u-boot-scsi.patch}
        '';
      };

    u-boot-image = u-boot + "/u-boot-spl.kwb";

    extlinux-conf-builder = import (pkgsPath + "/nixos/modules/system/boot/loader/generic-extlinux-compatible/extlinux-conf-builder.nix") {
      inherit pkgs;
    };

    image = pkgs.stdenv.mkDerivation rec {
      name = "helios-4-sd.img";

      buildInputs = with pkgs; [
        dosfstools
        e2fsprogs
        libfaketime
        mtools
        utillinux
      ];

      # This is just stitching large files together, no need to transmit them too
      # and fro.
      preferLocalBuild = true;

      bootSize = 120;
      buildCommand = ''
        ubootSizeBlocks=$(du -B 512 --apparent-size "${u-boot-image}" | awk '{ print $1 }')
        bootSizeBlocks=$((${toString bootSize} * 1024 * 1024 / 512))
        rootSizeBlocks=$(du -B 512 --apparent-size ${rootfsImage} | awk '{ print $1 }')
        imageSize=$((rootSizeBlocks * 512 + bootSizeBlocks * 512 + ubootSizeBlocks * 512 + 20 * 1024 * 1024))
        truncate -s "$imageSize" "$out"

        # type=b is 'W95 FAT32'
        # type=83 is 'Linux'
        sfdisk $out <<EOF
            label: dos
            label-id: 0x2178694e

            start=8M, size=$bootSizeBlocks, type=b, bootable
            start=${toString (8 + bootSize)}M, type=83
        EOF

        #
        # Copy uboot into the SD image
        #
        # eval $(partx $out -o START,SECTORS --nr 1 --pairs)
        # dd conv=notrunc if="${u-boot-image}" of="$out" seek=$START count=$SECTORS
        dd if="${u-boot-image}" of="$out" seek=1 bs=512

        #
        # Create a FAT32 /boot partition of suitable size into bootpart.img
        #
        eval $(partx $out -o START,SECTORS --nr 1 --pairs)
        truncate -s $((SECTORS * 512)) bootpart.img
        faketime "1970-01-01 00:00:00" mkfs.vfat -i 0x2178694e -n NIXOS_BOOT bootpart.img
        # Populate the files intended for /boot
        mkdir boot
        ${extlinux-conf-builder} -t 3 -c ${config.system.build.toplevel} -d ./boot
        # Copy the populated /boot into the SD imag
        (cd boot; mcopy -bpsvm -i ../bootpart.img ./* ::)
        dd conv=notrunc if=bootpart.img of=$out seek=$START count=$SECTORS

        #
        # Copy the rootfs into the SD image
        #
        eval $(partx $out -o START,SECTORS --nr 2 --pairs)
        dd conv=notrunc if=${rootfsImage} of=$out seek=$START count=$SECTORS
      '';
    };

in {
  inherit storePaths u-boot image;
}
