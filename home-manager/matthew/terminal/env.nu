$env.PATH = (
  $env.PATH
  | split row (char esep)
  | append /usr/local/bin
  | append /home/matthew/.nix-profile/bin
  | append /nix/var/nix/profiles/default/bin
  | append ($env.HOME | path join .cargo/bin)
  | append ($env.HOME | path join .local bin)
  | uniq # filter so the paths are unique
) 

$env.EDITOR = nvim

