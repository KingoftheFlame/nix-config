{ config, pkgs, inputs, ... }:
{
  home.packages = with pkgs; [
    wslu
  ];
}
