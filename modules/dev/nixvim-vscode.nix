# VSCode Neovim init file (extracts init-vscode.lua from nixvim config)
{ inputs, ... }:
{
  # Standalone nvim-vscode package (available on all configured systems)
  perSystem = { system, ... }: {
    packages.nvim-vscode =
      inputs.nixvim.legacyPackages.${system}.makeNixvim (import ../../nixvim-vscode.nix);
  };

  flake.modules.homeManager.nixvimVscode =
    { pkgs, ... }:
    let
      nixvimPkgs = inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      nvimVscode = nixvimPkgs.makeNixvim (import ../../nixvim-vscode.nix);
      nvimWrapperText = builtins.readFile "${nvimVscode}/bin/nvim";
      parts = pkgs.lib.strings.splitString " -u " nvimWrapperText;
      initVscodePath =
        if (builtins.length parts) < 2 then
          throw "Could not find -u path in wrapped nvim script"
        else
          let
            tail = builtins.elemAt parts 1;
            firstToken = builtins.head (pkgs.lib.strings.splitString " " tail);
          in
          firstToken;
    in
    {
      home.file.".config/nvim/init-vscode.lua".source = initVscodePath;
    };
}
