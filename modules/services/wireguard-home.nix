# WireGuard split tunnel to the homelab (server: apps/wireguard in the
# home-infrastructure-flux cluster repo, home.jevy.org:51820/udp).
#
# Manual on/off, never autostarted: on home wifi the tunnel is pointless.
#   sudo systemctl start wg-quick-wg-home   # up
#   sudo systemctl stop  wg-quick-wg-home   # down
#   sudo wg show wg-home                     # handshake / transfer counters
#
# Why wg-quick and not a NetworkManager profile: nothing here manages NM
# profiles declaratively (no ensureProfiles), and wg-quick takes the keys from
# root-only files at runtime via privateKeyFile/presharedKeyFile.
#
# KEYS ARE NOT IN THIS REPO OR THE STORE. They live in root-owned 0600 files
# under /etc/wireguard, pulled once from 1Password (Private vault, item
# "Q4bex7soe6nsbtia5n6fxcts74", attachment lenovo-p14s.conf). sops-nix here is
# home-manager-only (user-owned secrets), so it doesn't fit a root service.
#
# DNS: this machine uses openresolv (no systemd-resolved), which has no
# per-domain routing. wg-quick registers the DNS below with `resolvconf -x`
# (exclusive), so ALL DNS goes to 192.168.1.218 while the tunnel is up and
# reverts when it goes down.
#
# Tailscale conflict: accept-routes is on (RouteAll). If any tailnet node
# advertises 192.168.1.0/24, tailscale's table 52 (ip rule 5270) wins over the
# main-table route wg-quick adds, and LAN traffic goes via Tailscale instead.
# Also, a foreign network that is itself 192.168.1.0/24 will shadow the tunnel.
{ ... }:
{
  flake.modules.nixos.wireguardHome =
    { ... }:
    {
      networking.wg-quick.interfaces.wg-home = {
        autostart = false;
        address = [ "10.200.0.3/32" ];
        dns = [ "192.168.1.218" ];
        mtu = 1280;
        privateKeyFile = "/etc/wireguard/wg-home.key";

        peers = [
          {
            publicKey = "97R2xMZQaWArH1rap3JupmSRSy6zHqv8mQnzAcYLEC0=";
            presharedKeyFile = "/etc/wireguard/wg-home.psk";
            endpoint = "home.jevy.org:51820";
            allowedIPs = [
              "192.168.1.0/24"
              "10.200.0.0/24"
            ];
            persistentKeepalive = 25;
          }
        ];
      };
    };
}
