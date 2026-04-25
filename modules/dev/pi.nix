# Pi terminal coding agent
{ inputs, ... }:
{
  flake.modules.nixos.pi =
    { ... }:
    {
      imports = [ inputs.pi-mono.nixosModules.default ];

      programs.pi.coding-agent = {
        enable = true;
        users = [ "jevin" ];
      };
    };
}
