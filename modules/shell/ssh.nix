# SSH client configuration
{ ... }:
{
  flake.modules.homeManager.ssh = { config, ... }: {
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      includes = [ "config.local" ];
      settings."*" = {
        IdentityFile = "${config.sops.secrets.ssh_private_key.path}";
        AddKeysToAgent = "yes";
      };
    };

    home.file.".ssh/id_ed25519.pub".text =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICLzgDQQ5nqhEmiNZwdU8+SXxbl0tC3LLNAa+kO4KKNw jevin@quickjack.ca\n";
  };
}
