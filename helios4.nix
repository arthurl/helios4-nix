{ config, pkgs, ... }:
let
  crossPkgs = import pkgs.path {
    crossSystem = { system="armv7l-linux"; };
    system="x86_64-linux";
  };

in

{
  imports = [
  ];

  # Build the kernel on on x86-64
  # A patch is included to get both PWM fans working
  boot.kernelPackages = with crossPkgs;
    let linux_helios4 = linux_4_19.override {
          kernelPatches = [
            kernelPatches.bridge_stp_helper
            kernelPatches.modinst_arg_list_too_long
            {name = "helios4-fan"; patch = ./patches/helios4-fan.patch;}
          ];
          defconfig = "mvebu_v7_defconfig";
          structuredExtraConfig =
            with import (pkgs.path + "/lib/kernel.nix") { inherit lib; };
            { DRM = no; };
        };
    in  recurseIntoAttrs (linuxPackagesFor linux_helios4);

  boot.initrd.availableKernelModules = [ "ahci_mvebu" ];

  boot.kernelModules = [ "lm75" ];

  systemd.services.fancontrol = {
    description = "fancontrol daemon";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Restart = "always";
      RestartSec = "10s";
      ExecStart =
        let conf = pkgs.writeText "fancontrol.conf" ''
          # Helios4 PWM Fan Control Configuration
          # Temp source : /dev/thermal-board
          INTERVAL=10
          FCTEMPS=/dev/fan-j10/pwm1=/dev/thermal-board/temp1_input /dev/fan-j17/pwm1=/dev/thermal-board/temp1_input
          MINTEMP=/dev/fan-j10/pwm1=35  /dev/fan-j17/pwm1=35
          MAXTEMP=/dev/fan-j10/pwm1=60  /dev/fan-j17/pwm1=60
          MINSTART=/dev/fan-j10/pwm1=20 /dev/fan-j17/pwm1=20
          MINSTOP=/dev/fan-j10/pwm1=29  /dev/fan-j17/pwm1=29
          MINPWM=0
        '';
        in "${pkgs.lm_sensors}/sbin/fancontrol ${conf}";
    };
  };

  services.udev.extraRules = ''
    # Helios4 persistent hwmon

    ACTION=="remove", GOTO="helios4_hwmon_end"

    #
    KERNELS=="j10-pwm", SUBSYSTEMS=="platform", ENV{_HELIOS4_FAN_}="j10", ENV{_IS_HELIOS4_FAN_}="1", ENV{IS_HELIOS4_HWMON}="1"
    KERNELS=="j17-pwm", SUBSYSTEMS=="platform", ENV{_HELIOS4_FAN_}="j17", ENV{_IS_HELIOS4_FAN_}="1", ENV{IS_HELIOS4_HWMON}="1"
    KERNELS=="0-004c", SUBSYSTEMS=="i2c", DRIVERS=="lm75", ENV{IS_HELIOS4_HWMON}="1"

    SUBSYSTEM!="hwmon", GOTO="helios4_hwmon_end"

    ENV{HWMON_PATH}="/sys%p"
    #
    ATTR{name}=="f1072004mdiomii00", ENV{IS_HELIOS4_HWMON}="1", ENV{HELIOS4_SYMLINK}="/dev/thermal-eth"
    ATTR{name}=="armada_thermal", ENV{IS_HELIOS4_HWMON}="1", ENV{HELIOS4_SYMLINK}="/dev/thermal-cpu"
    #
    ENV{IS_HELIOS4_HWMON}=="1", ATTR{name}=="lm75", ENV{HELIOS4_SYMLINK}="/dev/thermal-board"
    ENV{_IS_HELIOS4_FAN_}=="1", ENV{HELIOS4_SYMLINK}="/dev/fan-$env{_HELIOS4_FAN_}"

    #
    ENV{IS_HELIOS4_HWMON}=="1", RUN+="${pkgs.coreutils}/bin/ln -sf $env{HWMON_PATH} $env{HELIOS4_SYMLINK}"

    LABEL="helios4_hwmon_end"
  '';
}
