{ config, lib, pkgs, ... }:

let
  cfg = config.services.mdatp;
in
{
  options.services.mdatp = {
    enable = lib.mkEnableOption "Whether to enable Microsoft Defender Advanced Threat Protection.";

    package = lib.mkPackageOption pkgs "mdatp" { };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.overlays = [ (import ../overlay.nix) ];

    environment.systemPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];

    users.users.mdatp = {
      group = "mdatp";
      isSystemUser = true;
    };

    users.groups.mdatp = { };
  };

  meta = {
    maintainers = with lib.maintainers; [ epetousis ];
  };
}
