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

#Note for future, if path is broken it is because something else in this file broke with an update
#this makes the whole file not get compiled

$env.EDITOR = 'hx'

$env.XDG_DATA_DIRS = ($env.HOME | path join .nix-profile/share:$HOME/.share:"${XDG_DATA_DIRS:-/usr/local/share/:/usr/share/}")
