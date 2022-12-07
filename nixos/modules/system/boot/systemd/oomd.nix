{ config, lib, ... }: let

  cfg = config.systemd.oomd;

in {
  options.systemd.oomd = {
    enable = lib.mkEnableOption (lib.mdDoc "the `systemd-oomd` OOM killer") // { default = true; };

    # Fedora enables the first and third option by default. See the 10-oomd-* files here:
    # https://src.fedoraproject.org/rpms/systemd/tree/acb90c49c42276b06375a66c73673ac351025597
    enableRootSlice = lib.mkEnableOption (lib.mdDoc "oomd on the root slice (`-.slice`)");
    enableSystemSlice = lib.mkEnableOption (lib.mdDoc "oomd on the system slice (`system.slice`)");
    enableUserServices = lib.mkEnableOption (lib.mdDoc "oomd on all user services (`user@.service`)");

    dryRun = lib.mkEnableOption (lib.mdDoc "dry run of oomd where it will only print what it would have killed.");

    logLevel = lib.mkOption {
      type = lib.types.enum ["debug" "notice" "info" "warning" "err" "crit" "alert" "emerg"];
      default = "info";
      description = "Log level for systemd-oomd";
    };

    extraConfig = lib.mkOption {
      type = with lib.types; attrsOf (oneOf [ str int bool ]);
      default = {};
      example = lib.literalExpression ''{ DefaultMemoryPressureDurationSec = "20s"; }'';
      description = lib.mdDoc ''
        Extra config options for `systemd-oomd`. See {command}`man oomd.conf`
        for available options.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.dryRun -> cfg.logLevel == "debug";
        message = ''
          Due to a bug in systemd: https://github.com/systemd/systemd/pull/25670
          systemd.oomd.dryRun requires that systemd.oomd.logLevel be
          "debug".
        '';
      }
    ];
    systemd.additionalUpstreamSystemUnits = [
      "systemd-oomd.service"
      "systemd-oomd.socket"
    ];

    systemd.services.systemd-oomd = {
      # TODO: how do you override ExecStart for an upstream unit?
      wantedBy = [ "multi-user.target" ];
      environment = {
        SYSTEMD_LOG_LEVEL = cfg.logLevel;
      };
    };

    environment.etc."systemd/oomd.conf".text = lib.generators.toINI {} {
      OOM = cfg.extraConfig;
    };

    systemd.oomd.extraConfig.DefaultMemoryPressureDurationSec = lib.mkDefault "20s"; # Fedora default

    users.users.systemd-oom = {
      description = "systemd-oomd service user";
      group = "systemd-oom";
      isSystemUser = true;
    };
    users.groups.systemd-oom = { };

    systemd.slices."-".sliceConfig = lib.mkIf cfg.enableRootSlice {
      ManagedOOMSwap = "kill";
    };
    systemd.slices."system".sliceConfig = lib.mkIf cfg.enableSystemSlice {
      ManagedOOMSwap = "kill";
    };
    systemd.services."user@".serviceConfig = lib.mkIf cfg.enableUserServices {
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "50%";
    };
  };
}
