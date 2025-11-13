{pkgs, config, lib,  ...}:
{
  options = {
    virt_members = lib.mkOption{
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = {

    programs.virt-manager.enable = true;

    users.groups.libvirtd.members = config.virt_members;

    virtualisation.libvirtd.enable = true;

    virtualisation.spiceUSBRedirection.enable = true;
    services.spice-vdagentd.enable = true;


    environment.systemPackages = with pkgs;[
      virt-manager
      virt-viewer
      spice 
      spice-gtk
      spice-protocol
      virtio-win
      win-spice
    
      #docker stuff
      dive # look into docker image layers
      podman-tui # status of containers in the terminal
      #docker-compose # start group of containers for dev
      podman-compose # start group of containers for dev
    
    ];




    #podman
    virtualisation.podman = {
      enable = true;

      dockerCompat = true;

      # Required for containers under podman-compose to be able to talk to each other.
      defaultNetwork.settings.dns_enabled = true;
      
    };
    
    #Docker
    # virtualisation.docker.enable = true;
    # virtualisation.docker.rootless = {
    #   enable = true;
    #   setSocketVariable = true;
    # };

  };
}
