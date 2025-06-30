{ self, pkgs }:

pkgs.nixosTest {
  name = "test-mdatp";
  nodes.machine = { config, pkgs, ... }: {
    imports = [
      self.nixosModules.mdatp
    ];

    services.mdatp = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
    };

    system.stateVersion = "24.11";
  };

  testScript = ''
    machine.wait_for_unit("mdatp.service")
    machine.succeed("mdatp version")
  '';
}
