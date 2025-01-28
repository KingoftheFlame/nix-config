 { config, pkgs, inputs, outputs,  ... }:
{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = [
    #Add any missing dynamic libraries here instead of in enviroment.systempackages
  ];
}
