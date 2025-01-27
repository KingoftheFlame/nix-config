# Add your reusable home-manager modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  # List your module files here
  # my-module = import ./my-module.nix;

  #terminal
  terminal = import ./terminal;
  helix = import ./helix;
  neovim = import ./neovim;

  gui = import ./gui;

  sci-tools = import ./sci-tools.nix;
}
