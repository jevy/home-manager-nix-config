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
      vim-gitgutter
      nvim-tree-lua
      nvim-web-devicons
      fzf-vim
      vim-rooter
      vim-easy-align
      vim-dirdiff
      vim-fugitive
      rnvimr
      leap-nvim
      vim-rails
      indent-blankline-nvim
      rainbow-delimiters-nvim

      (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
        p.ruby
        p.nix
        p.regex
        p.yaml
        p.json
        p.markdown
        p.dockerfile
        p.lua
        p.javascript
        p.typescript
        p.latex
      ]))


      # completion-treesitter
      nvim-treesitter-textobjects
      nvim-treesitter-context
      vim-lsp
      nvim-lspconfig

      # Text completion
      # cmp-nvim-lsp
      # nvim-cmp

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
      ltex-ls
      terraform-ls
    ];

    extraConfig = builtins.concatStringsSep "\n" [
        (lib.strings.fileContents ./base.vim)
      ''
        lua << EOF
        require("nvim-tree").setup()
        vim.api.nvim_set_keymap('n', '<C-n>', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('n', '<C-f>', ':Telescope find_files<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('n', '<C-g>', ':Telescope live_grep<CR>', { noremap = true, silent = true })

        require('leap').add_default_mappings()

        require'treesitter-context'.setup{
          enable = true,
          max_lines = 0,
          min_window_height = 0,
          line_numbers = true,
        }

        require("nvim-treesitter.configs").setup {
          highlight = {
            enable = true,
          },
          indent = {
            enable = true,
          }
        }

        require'nvim-treesitter.configs'.setup {
          textobjects = {
            select = {
              enable = true,

              lookahead = true,
              keymaps = {
                -- You can use the capture groups defined in textobjects.scm
                ["a="] = { query = "@assignment.outer", desc = "Select outer part of an assignment" },
                ["i="] = { query = "@assignment.inner", desc = "Select inner part of an assignment" },
                ["l="] = { query = "@assignment.lhs", desc = "Select left hand side of an assignment" },
                ["r="] = { query = "@assignment.rhs", desc = "Select right hand side of an assignment" },

                ["aa"] = { query = "@parameter.outer", desc = "Select outer part of a parameter/argument" },
                ["ia"] = { query = "@parameter.inner", desc = "Select inner part of a parameter/argument" },

                ["ai"] = { query = "@conditional.outer", desc = "Select outer part of a conditional" },
                ["ii"] = { query = "@conditional.inner", desc = "Select inner part of a conditional" },

                ["al"] = { query = "@loop.outer", desc = "Select outer part of a loop" },
                ["il"] = { query = "@loop.inner", desc = "Select inner part of a loop" },

                ["af"] = { query = "@call.outer", desc = "Select outer part of a function call" },
                ["if"] = { query = "@call.inner", desc = "Select inner part of a function call" },

                ["am"] = { query = "@function.outer", desc = "Select outer part of a method/function definition" },
                ["im"] = { query = "@function.inner", desc = "Select inner part of a method/function definition" },

                ["ac"] = { query = "@class.outer", desc = "Select outer part of a class" },
                ["ic"] = { query = "@class.inner", desc = "Select inner part of a class" },
              },
            },
          },
        }

        require("ibl").setup()

        require'lspconfig'.ltex.setup{}
        require'lspconfig'.rnix.setup{}
        require'lspconfig'.terraformls.setup{}
        require'lspconfig'.solargraph.setup{
          settings = {
            solargraph = {
              diagnostics = true
            }
          }
        }

        EOF
      ''
    ];
  };
}
