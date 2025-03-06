{pkgs, config, ...}:
{
  home.packages = with pkgs;[
    # arduino
    # arduino-cli
    arduino-ide
    kdePackages.ghostwriter
  
  ];
}
  

