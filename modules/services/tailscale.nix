# Tailscale VPN configuration
{ ... }:
{
  flake.modules.nixos.tailscale =
    { ... }:
    {
      services.tailscale = {
        enable = true;
        useRoutingFeatures = "client";
        extraSetFlags = [ "--accept-dns=true" ];
      };

      # Wait for network before starting tailscaled
      systemd.services.tailscaled.after = [ "systemd-networkd-wait-online.service" ];
    };
}
