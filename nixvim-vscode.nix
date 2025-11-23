{
  # VSCode-specific Neovim config for nixvim standalone builds
  # Keep this minimal; VSCode handles UI, LSP, etc.
  opts = {
    # number = true;
    # relativenumber = true;
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

  # Only include lightweight, VSCode-friendly plugins
  plugins = {
    # which-key.enable = true;
    leap.enable = true;
    # web-devicons.enable = true;

    # Treesitter for better syntax/indent; keep grammar set modest
    treesitter = {
      enable = false;
      settings = {
        indent.enable = true;
        highlight.enable = false;
      };
    };

    # Formatting/LSP are generally handled by VSCode; omit here by default
    lsp.enable = false;
    lsp-format.enable = false;
  };

  extraConfigLua = ''
    -- Only apply this config when running inside VSCode's neovim
    if not vim.g.vscode then
      vim.o.hlsearch = false
      return
    end

    -- VSCode renders line numbers; disable Neovim's number columns here to avoid duplicates
    vim.opt.number = false
    vim.opt.relativenumber = false

    -- VSCode-specific keymaps or tweaks go here
    -- Example: map <C-f> to Telescope find_files
    local map = vim.keymap.set

    -- Make jumplist behave like Neovim defaults using VSCode's jumplist
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
}
