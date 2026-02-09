# 1Password GUI
{ ... }:
{
  flake.modules.nixos.onepassword =
    { pkgs, ... }:
    {
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ "jevin" ];
        package = pkgs._1password-gui;
      };
    };
}
