# VSCode Neovim init file (extracts init-vscode.lua from nixvim config)
{ inputs, ... }:
let
  nixvimVscodeConfig = {
    opts = {
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      splitbelow = true;
      showmatch = true;
      ignorecase = true;
      scrolloff = 5;
      incsearch = true;
      writebackup = false;
      backup = false;
    };

    plugins = {
      leap.enable = true;

      treesitter = {
        enable = false;
        settings = {
          indent.enable = true;
          highlight.enable = false;
        };
      };

      lsp.enable = false;
      lsp-format.enable = false;
    };

    extraConfigLua = ''
      if not vim.g.vscode then
        vim.o.hlsearch = false
        return
      end

      vim.opt.number = false
      vim.opt.relativenumber = false

      local map = vim.keymap.set
      local ok_vscode, vscode = pcall(require, 'vscode')
      if ok_vscode then
        map('n', '<C-o>', function()
          vscode.action('workbench.action.navigateBack')
        end, { noremap = true, silent = true })
        map('n', '<C-i>', function()
          vscode.action('workbench.action.navigateForward')
        end, { noremap = true, silent = true })
      end
    '';
  };
in
{
  # Standalone nvim-vscode package (available on all configured systems)
  perSystem = { system, ... }: {
    packages.nvim-vscode =
      inputs.nixvim.legacyPackages.${system}.makeNixvim nixvimVscodeConfig;
  };

  flake.modules.homeManager.nixvimVscode =
    { pkgs, ... }:
    let
      nixvimPkgs = inputs.nixvim.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      nvimVscode = nixvimPkgs.makeNixvim nixvimVscodeConfig;
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
