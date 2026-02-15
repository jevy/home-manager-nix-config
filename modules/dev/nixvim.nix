# Nixvim configuration
{ inputs, ... }:
{
  flake.modules.homeManager.nixvim =
    { config, pkgs, ... }:
    {
      imports = [
        inputs.nixvim.homeModules.default
      ];

      # See the generated vimrc: nixvim-print-init
      programs.nixvim = {
        enable = true;
        defaultEditor = true;

        opts = {
          autoread = true;
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
          timeout = true;
          timeoutlen = 500;
        };
        vimAlias = true;
        viAlias = true;
        autoGroups = {
          "auto-reload" = { clear = true; };
        };
        autoCmd = [
          {
            event = ["FocusGained" "TermLeave" "BufEnter" "CursorHold" "CursorHoldI"];
            group = "auto-reload";
            callback = {
              __raw = ''
                function()
                  if vim.fn.mode() ~= 'c' then
                    vim.cmd('checktime')
                  end
                end
              '';
            };
          }
        ];
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
          # Trouble
          { mode = "n"; key = "<leader>xx"; action = "<cmd>Trouble diagnostics toggle<CR>"; options = { silent = true; desc = "Toggle diagnostics"; }; }
          { mode = "n"; key = "<leader>xw"; action = "<cmd>Trouble workspace_diagnostics toggle<CR>"; options = { silent = true; desc = "Workspace diagnostics"; }; }
          { mode = "n"; key = "<leader>xd"; action = "<cmd>Trouble document_diagnostics toggle<CR>"; options = { silent = true; desc = "Document diagnostics"; }; }
          { mode = "n"; key = "<leader>xq"; action = "<cmd>Trouble quickfix toggle<CR>"; options = { silent = true; desc = "Quickfix list"; }; }
          { mode = "n"; key = "]d"; action = "<cmd>Trouble diagnostic next<CR>"; options = { silent = true; desc = "Next diagnostic"; }; }
          { mode = "n"; key = "[d"; action = "<cmd>Trouble diagnostic prev<CR>"; options = { silent = true; desc = "Previous diagnostic"; }; }
        ];
        plugins = {
          gitsigns.enable = true;
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
              nixd.enable = true; # nix
              vtsls.enable = true; # TypeScript (modern replacement for ts_ls)
              kotlin_language_server.enable = true;
              marksman.enable = true;
              gopls.enable = true;
            };
          };
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
          conform-nvim = {
            enable = true;
            settings = {
              formatters_by_ft = {
                nix = ["alejandra"];
              };
            };
          };
          markview.enable = true;
          rainbow-delimiters.enable = true;
          telescope = {
            enable = true;
            extensions = {
              fzf-native.enable = true;
            };
          };
          todo-comments.enable = true;
          trouble.enable = true;
          which-key = {
            enable = true;
            settings = {
              preset = "modern";
              triggers = [
                { __unkeyed-1 = "<auto>"; mode = "nxso"; }
              ];
              spec = [
                { __unkeyed-1 = "<leader>a"; group = "AI/Claude"; }
                { __unkeyed-1 = "<leader>x"; group = "Trouble"; }
              ];
            };
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
              bigfile = { enabled = true; };
              notifier = { enabled = true; timeout = 3000; };
              quickfile = { enabled = true; };
              terminal = { enabled = true; };
            };
          };
          blink-cmp = {
            enable = true;
            settings = {
              sources = {
                default = ["lsp" "snippets" "buffer" "path"];
              };
              keymap = {
                "<C-space>" = ["show" "show_documentation" "hide_documentation"];
                "<C-e>" = ["hide" "fallback"];
                "<CR>" = ["accept" "fallback"];
                "<Tab>" = ["select_next" "fallback"];
                "<S-Tab>" = ["select_prev" "fallback"];
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
    };
}
