{
  config,
  pkgs,
  pkgsWithUnfree ? pkgs,
  ...
}:
{
  # See the generated vimrc: nixvim-print-init
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    # Symlink ecma/jsx query files needed for tsx/typescript treesitter inheritance
    extraFiles = {
      "queries/ecma".source = "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries/ecma";
      "queries/jsx".source = "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries/jsx";
    };
    opts = {
      relativenumber = true;
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
    vimAlias = true;
    viAlias = true;
    # Use extraPlugins - claudecode-nvim is the newer package (Dec 2025)
    extraPlugins = [
      pkgs.vimPlugins.claudecode-nvim
    ];
    keymaps = [
      # Escape insert mode with jj
      { mode = "i"; key = "jj"; action = "<Esc>"; options = { silent = true; desc = "Escape insert mode"; }; }
      # Flash: jump (using f instead of s, giving up native f)
      { mode = ["n" "x" "o"]; key = "f"; action.__raw = "function() require('flash').jump() end"; options = { silent = true; desc = "Flash"; }; }
      # Flash: treesitter selection
      { mode = ["n" "x" "o"]; key = "F"; action.__raw = "function() require('flash').treesitter() end"; options = { silent = true; desc = "Flash Treesitter"; }; }
      # Flash: toggle in search mode
      { mode = "c"; key = "<C-s>"; action.__raw = "function() require('flash').toggle() end"; options = { silent = true; desc = "Toggle Flash Search"; }; }
      # Treesitter incremental selection with grow/shrink
      { mode = ["n" "x" "o"]; key = "<C-space>"; action.__raw = ''
        function()
          require('flash').treesitter({
            actions = {
              ["<C-space>"] = "next",
              ["<BS>"] = "prev"
            }
          })
        end
      ''; options = { silent = true; desc = "Treesitter incremental selection"; }; }
      # Claude Code keymaps
      { mode = "n"; key = "<C-.>"; action = "<cmd>ClaudeCodeFocus<cr>"; options = { silent = true; desc = "Toggle Claude"; }; }
      { mode = "v"; key = "<C-.>"; action = "<cmd>ClaudeCodeSend<cr>"; options = { silent = true; desc = "Send to Claude"; }; }
      { mode = "n"; key = "<leader>ac"; action = "<cmd>ClaudeCode<cr>"; options = { silent = true; desc = "Toggle Claude"; }; }
      { mode = "n"; key = "<leader>af"; action = "<cmd>ClaudeCodeFocus<cr>"; options = { silent = true; desc = "Focus Claude"; }; }
      { mode = "n"; key = "<leader>am"; action = "<cmd>ClaudeCodeSelectModel<cr>"; options = { silent = true; desc = "Select model"; }; }
      { mode = "n"; key = "<leader>aa"; action = "<cmd>ClaudeCodeDiffAccept<cr>"; options = { silent = true; desc = "Accept diff"; }; }
      { mode = "n"; key = "<leader>ad"; action = "<cmd>ClaudeCodeDiffDeny<cr>"; options = { silent = true; desc = "Deny diff"; }; }
      # File tree
      { mode = "n"; key = "<C-n>"; action = "<cmd>NvimTreeToggle<CR>"; options = { silent = true; desc = "Toggle file tree"; }; }
      # Telescope
      { mode = "n"; key = "<C-f>"; action = "<cmd>Telescope find_files<CR>"; options = { silent = true; desc = "Find files"; }; }
      { mode = "n"; key = "<C-g>"; action = "<cmd>Telescope live_grep<CR>"; options = { silent = true; desc = "Live grep"; }; }
    ];
    plugins = {
      gitgutter.enable = true;
      lualine.enable = true;
      flash = {
        enable = true;
        settings = {
          label.min_pattern_length = 1;
          jump.autojump = true;
          modes = {
            # Disable char mode since we're using f for flash jump
            char.enabled = false;
          };
        };
      };
      project-nvim = {
        enable = true;
        autoLoad = true;
      };
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true; # nix
          # ts_ls.enable = true;
          kotlin_language_server.enable = true;
          marksman.enable = true;
          gopls.enable = true;
        };
      };
      lsp-format.enable = true;
      nvim-tree = {
        enable = true;
        settings = {
          disable_netrw = true;
          hijack_netrw = true;
          filters = {
            dotfiles = true;
          };
          update_focused_file = {
            enable = true;
          };
        };
      };
      none-ls = {
        enable = true;
        sources = {
          formatting = {
            alejandra.enable = true;
          };
        };
      };
      markview.enable = false;
      rainbow-delimiters.enable = false;
      telescope = {
        enable = true;
        extensions = {
          fzy-native.enable = true;
          fzf-native.enable = true;
        };
      };
      todo-comments.enable = true;
      trouble.enable = true;
      which-key = {
        enable = true;
        settings.spec = [
          { __unkeyed-1 = "<leader>a"; group = "AI/Claude"; }
        ];
      };
      web-devicons.enable = true;
      mini = {
        enable = true;
        modules = {
          ai = {
            n_lines = 500;
            search_method = "cover_or_next";
          };
          surround = {};  # sa/sd/sr (s is free now)
        };
      };
      snacks = {
        enable = true;
        settings = {
          terminal = { enabled = true; };
        };
      };
      luasnip.enable = true;
      friendly-snippets.enable = true;
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "buffer"; }
            { name = "path"; }
          ];
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = ''
              cmp.mapping(function(fallback)
                local luasnip = require('luasnip')
                if cmp.visible() then
                  cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                  luasnip.expand_or_jump()
                else
                  fallback()
                end
              end, { 'i', 's' })
            '';
            "<S-Tab>" = ''
              cmp.mapping(function(fallback)
                local luasnip = require('luasnip')
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, { 'i', 's' })
            '';
          };
        };
      };
      treesitter = {
        enable = true;
        highlight.enable = true;
        indent.enable = true;
        # Using default allGrammars - remove this comment and add grammarPackages back if you want to limit parsers
      };
      treesitter-context.enable = true;
    };
    extraConfigLua = ''
      -- Option 1: Use Java parser for Kotlin (better indent, but highlighting may be off)
      -- vim.treesitter.language.register('java', 'kotlin')

      -- Option 2: Use cindent for Kotlin (keeps kotlin highlighting, decent indent)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'kotlin',
        callback = function()
          vim.bo.cindent = true
        end,
      })

      -- Claude Code setup (via extraPlugins)
      require('claudecode').setup({
        terminal = {
          split_side = "right",
          split_width_percentage = 0.35,
          provider = "snacks",
          snacks_win_opts = {
            position = "right",
            keys = {
              claude_hide = {
                "<C-.>",
                function(self) self:hide() end,
                mode = "t",
                desc = "Hide Claude",
              },
            },
          },
        },
      })
    '';
  };
}
