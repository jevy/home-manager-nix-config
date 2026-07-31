# 1Password GUI + CLI
{ ... }:
{
  # CLI only, for hosts with no NixOS module to lean on (mac-work). The NixOS
  # `programs._1password` below wraps `op` setuid-root so the desktop app can
  # authorise it; there's no darwin equivalent, so this is the plain package.
  #
  # Caveat on macOS: the desktop app authenticates the CLI by checking its code
  # signature against AgileBits', and a nixpkgs-built `op` isn't signed by them
  # — so "Integrate with 1Password CLI" (Touch ID unlock) won't pick this up.
  # `eval $(op signin)` with an account password / service-account token works.
  flake.modules.homeManager.onepasswordCli =
    { pkgs, ... }:
    {
      home.packages = [ pkgs._1password-cli ];
    };

  flake.modules.nixos.onepassword =
    { pkgs, ... }:
    {
      programs._1password = {
        enable = true;
      };
      programs._1password-gui = {
        enable = true;
        polkitPolicyOwners = [ "jevin" ];
        package = pkgs._1password-gui;
      };
    };
}
