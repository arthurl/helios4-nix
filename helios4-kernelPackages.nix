{ pkgs }:

let
  crossPkgs = import pkgs.path {
    crossSystem = { system="armv7l-linux"; };
    system="x86_64-linux";
  };

  linux_helios4 = with crossPkgs; linux_4_19.override {
    kernelPatches = [
      kernelPatches.bridge_stp_helper
      kernelPatches.modinst_arg_list_too_long
      {name = "helios4-fan"; patch = ./patches/helios4-fan.patch;}
    ];
    defconfig = "mvebu_v7_defconfig";
    structuredExtraConfig =
      with import (pkgs.path + "/lib/kernel.nix") { inherit lib; version = null; };
      { DRM = no; };
  };
in

with crossPkgs;
recurseIntoAttrs (linuxPackagesFor linux_helios4)
