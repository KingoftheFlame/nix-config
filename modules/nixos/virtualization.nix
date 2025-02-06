{pkgs, config, lib,  ...}:
{
  options = {
    virt_members = lib.mkOption{
      type = lib.types.listOf lib.types.string;
      default = [];
    };
  };

  config = {

    programs.virt-manager.enable = true;

    users.groups.libvirtd.members = config.virt_members;

    virtualisation.libvirtd.enable = true;

    virtualisation.spiceUSBRedirection.enable = true;
    
    #Docker
    virtualisation.docker.enable = true;
    virtualisation.docker.rootless = {
      enable = true;
      setSocketVariable = true;
    };

  };
}
