{config, pkgs, lib, ...}: {
  programs.nushell.extraEnv = "$env.BROWSER = \'wslview\'";
}
