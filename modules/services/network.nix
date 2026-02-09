# Network and firewall configuration
{ ... }:
{
  flake.modules.nixos.network =
    { ... }:
    {
      networking.hosts = { "127.0.0.1" = [ "db" ]; };
      networking.networkmanager.enable = true;
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [
          80 22
          8080  # Python connection test
          27124 # Obsidian REST for MCP
          27123 # Obsidian REST for MCP
        ];
        extraCommands = ''
          # Allow Docker containers to reach TypeStream server
          iptables -A nixos-fw -s 172.19.0.0/16 -p tcp --dport 4242 -j ACCEPT
          iptables -A nixos-fw -s 172.17.0.0/16 -p tcp --dport 4242 -j ACCEPT
        '';
      };
    };
}
