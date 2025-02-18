{outputs, internet, ...}:
{
  imports = [
    ./firefox
    ./messaging.nix
    ./internet.nix
  ];
}
