{ config, pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
    plugins = with pkgs.vimPlugins; [
      vim-airline
      vim-surround
      vim-commentary
      vim-json
      vim-markdown
      goyo-vim
      # ranger-vim
      base16-vim
      vim-nix
      gruvbox-material
      vim-indent-guides
      vim-gitgutter
      nvim-tree-lua
      nvim-web-devicons # for nvim-tree
      fzf-vim
      vim-rooter
      vim-easy-align
      vim-dirdiff
      vim-fugitive

      # Tree Sitter stuff
      (nvim-treesitter.withPlugins (
        plugins: with pkgs.tree-sitter-grammars; [
          tree-sitter-ruby
          tree-sitter-nix
          tree-sitter-regex
          tree-sitter-yaml
          tree-sitter-vim
          tree-sitter-json
          tree-sitter-markdown
          tree-sitter-dockerfile
          tree-sitter-lua

        ]
      ))
      # completion-treesitter
      nvim-treesitter-textobjects
      nvim-treesitter-context
      vim-lsp
      nvim-lspconfig
      # nvim-cmp
      # cmp-nvim-lsp
      # cmp_luasnip
      # luasnip

      plenary-nvim
      telescope-nvim
      telescope-fzy-native-nvim
      (pkgs.vimUtils.buildVimPlugin {
        name = "vim-ai";
        src = pkgs.fetchFromGitHub {
          owner = "madox2";
          repo = "vim-ai";
          rev = "4692eec84b5aa9d95256bef515bd1d17471e5570";
          sha256 = "YRN8aJX7TG1qX89JgfzE1oBhU7dncC3LJov7+kFbOg8=";  # Replace with the correct SHA256 hash
        };
      })
    ];

    extraPackages = with pkgs; [
      # Ruby LSP - https://blog.backtick.consulting/neovims-built-in-lsp-with-ruby-and-rails/
      rubyPackages.solargraph
      rnix-lsp
      ltex-ls
    ];

    extraConfig = builtins.concatStringsSep "\n" [
        (lib.strings.fileContents ./base.vim)
      ''
        lua << EOF
        require("nvim-tree").setup()
        vim.api.nvim_set_keymap('n', '<C-n>', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('n', '<C-f>', ':Telescope find_files<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('n', '<C-g>', ':Telescope live_grep<CR>', { noremap = true, silent = true })

        require("nvim-treesitter.configs").setup {
          highlight = {
            enable = true,
          },
          indent = {
            enable = true,
          }
        }

        require('leap').add_default_mappings()

        require'lspconfig'.ltex.setup{}
        require'lspconfig'.rnix.setup{}
        require'lspconfig'.solargraph.setup{}

        -- Global mappings.
        -- See `:help vim.diagnostic.*` for documentation on any of the below functions
        vim.keymap.set('n', '<space>e', vim.diagnostic.open_float)
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev)
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next)
        vim.keymap.set('n', '<space>q', vim.diagnostic.setloclist)

        -- Use LspAttach autocommand to only map the following keys
        -- after the language server attaches to the current buffer
        vim.api.nvim_create_autocmd('LspAttach', {
          group = vim.api.nvim_create_augroup('UserLspConfig', {}),
          callback = function(ev)
            -- Enable completion triggered by <c-x><c-o>
            vim.bo[ev.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'

            -- Buffer local mappings.
            -- See `:help vim.lsp.*` for documentation on any of the below functions
            local opts = { buffer = ev.buf }
            vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
            vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
            vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
            vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
            vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
            vim.keymap.set('n', '<space>wa', vim.lsp.buf.add_workspace_folder, opts)
            vim.keymap.set('n', '<space>wr', vim.lsp.buf.remove_workspace_folder, opts)
            vim.keymap.set('n', '<space>wl', function()
              print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
            end, opts)
            vim.keymap.set('n', '<space>D', vim.lsp.buf.type_definition, opts)
            vim.keymap.set('n', '<space>rn', vim.lsp.buf.rename, opts)
            vim.keymap.set({ 'n', 'v' }, '<space>ca', vim.lsp.buf.code_action, opts)
            vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
            vim.keymap.set('n', '<space>f', function()
              vim.lsp.buf.format { async = true }
            end, opts)
          end,
        })

        EOF
      ''
      ];
  };
}
