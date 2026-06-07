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
        nixpkgs.source = pkgs.path;

        opts = {
          autoread = true;
          relativenumber = true;
          expandtab = true;
          shiftwidth = 2;
          tabstop = 2;
          splitbelow = true;
          showmatch = true;
          ignorecase = true;
          wrap = false;
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
          {
            event = ["FileType"];
            pattern = ["markdown"];
            callback = {
              __raw = ''
                function()
                  vim.wo.wrap = true
                  vim.wo.linebreak = true
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
          # GraphQL / FE→BE flow navigation. The whole point: keep pressing the
          # standard LSP keys. gd / gri / grr (defined flow-aware in extraConfigLua)
          # cross the one seam the compiler can't — a gql field → its resolver,
          # keyed by name as a string — when the cursor sits inside a gql`` block,
          # and behave like plain LSP everywhere else. Walking a request top to bottom:
          #
          #   hop                              key   in a gql`` block        elsewhere
          #   ──────────────────────────────  ────  ──────────────────────  ─────────────────
          #   component → hook → gql document  gd    schema SDL definition   LSP definition
          #   gql field → resolver  (the seam) gri   resolver impl.          LSP implementation
          #   reverse: which FE selects field  grr   frontend gql usages     LSP references
          #   resolver → service → Prisma/etc  <leader>go    LSP outgoing-call tree (Trouble)
          #   reverse: who calls this          <leader>gi    LSP incoming calls
          #
          # <leader>g{r,s,u} below are explicit always-grep aliases (resolver / schema /
          # usages) for when you're not in a gql`` block or treesitter guesses wrong.
          # Single match jumps; multiple open a Trouble quickfix list. The Flow*
          # commands and the smart gd/gri/grr maps are defined in extraConfigLua.
          { mode = "n"; key = "<leader>gr"; action = "<cmd>FlowResolver<cr>"; options = { silent = true; desc = "Field → resolver (cross the wire)"; }; }
          { mode = "n"; key = "<leader>gu"; action = "<cmd>FlowUsages<cr>"; options = { silent = true; desc = "Field → frontend usages"; }; }
          { mode = "n"; key = "<leader>gs"; action = "<cmd>FlowSchema<cr>"; options = { silent = true; desc = "Field → schema SDL"; }; }
          { mode = "n"; key = "<leader>go"; action = "<cmd>Trouble lsp_outgoing_calls toggle focus=true<cr>"; options = { silent = true; desc = "Outgoing calls (descend FE→BE)"; }; }
          { mode = "n"; key = "<leader>gi"; action = "<cmd>Trouble lsp_incoming_calls toggle focus=true<cr>"; options = { silent = true; desc = "Incoming calls (who calls this)"; }; }
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
          # Window navigation — skip the <C-w> prefix. C-j/C-k = down/up to match
          # j/k motion (so C-k hops up to code, C-j down to a Trouble list).
          { mode = "n"; key = "<C-h>"; action = "<C-w>h"; options = { silent = true; desc = "Window left"; }; }
          { mode = "n"; key = "<C-j>"; action = "<C-w>j"; options = { silent = true; desc = "Window down"; }; }
          { mode = "n"; key = "<C-k>"; action = "<C-w>k"; options = { silent = true; desc = "Window up"; }; }
          { mode = "n"; key = "<C-l>"; action = "<C-w>l"; options = { silent = true; desc = "Window right"; }; }
          # goto-preview: peek definition in a float; press gp again inside it to descend.
          { mode = "n"; key = "gp"; action.__raw = "function() require('goto-preview').goto_preview_definition() end"; options = { silent = true; desc = "Peek definition"; }; }
          { mode = "n"; key = "gP"; action.__raw = "function() require('goto-preview').close_all_win() end"; options = { silent = true; desc = "Close all peeks"; }; }
          # Branch review — see what changed vs main without leaving the file.
          # <leader>gc lists changed files in Trouble; the <leader>h group drives the
          # gutter: toggle signs vs main, expand a hunk inline, jump hunk-to-hunk.
          { mode = "n"; key = "<leader>gc"; action = "<cmd>ChangedFiles<cr>"; options = { silent = true; desc = "Changed files vs main → Trouble"; }; }
          { mode = "n"; key = "<leader>hb"; action = "<cmd>BranchSigns<cr>"; options = { silent = true; desc = "Toggle gutter signs vs main"; }; }
          { mode = "n"; key = "<leader>hp"; action.__raw = "function() require('gitsigns').preview_hunk_inline() end"; options = { silent = true; desc = "Expand hunk inline"; }; }
          { mode = "n"; key = "]h"; action.__raw = "function() require('gitsigns').nav_hunk('next') end"; options = { silent = true; desc = "Next hunk"; }; }
          { mode = "n"; key = "[h"; action.__raw = "function() require('gitsigns').nav_hunk('prev') end"; options = { silent = true; desc = "Previous hunk"; }; }
        ];
        plugins = {
          gitsigns.enable = true;
          lualine.enable = true;
          # Peek a definition in a float (gp); press gp again inside it to stack
          # another level deeper. We own the keymaps, so disable the defaults.
          goto-preview = {
            enable = true;
            settings.default_mappings = false;
          };
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
              # GraphQL: schema-aware nav/completion on embedded gql`` operations.
              # Needs a graphql.config.* in the project pointing at the SDL
              # (covenant-web: apps/client/tmp/*.schema.graphql). Without it the
              # server simply doesn't attach, so this is safe in other repos.
              graphql.enable = true;
            };
            # Go-to-definition family. gd / gri (implementation) / grr (references)
            # are defined in extraConfigLua as flow-aware wrappers — they cross the
            # gql→server wire inside a gql`` block and fall back to plain LSP
            # elsewhere — so they're intentionally NOT set here. Neovim 0.11 still
            # provides grn (rename), gra (code action), gO (symbols).
            keymaps.lspBuf = {
              gD = "declaration";
              gy = "type_definition";
              K = "hover";
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
          render-markdown.enable = true;
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
                { __unkeyed-1 = "<leader>g"; group = "GraphQL/flow"; }
                { __unkeyed-1 = "<leader>h"; group = "Git hunks"; }
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
                default = ["lsp" "snippets" "path"];
              };
              enabled = {
                __raw = ''
                  function()
                    return vim.bo.filetype ~= "mail"
                  end
                '';
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


          -- ─── GraphQL flow navigation (FE → resolver → service → DB) ───────────
          -- In a typed TS/GraphQL stack every hop is a plain LSP go-to-definition
          -- EXCEPT one: a field inside a gql`` document references its resolver by
          -- *name as a string*, so the compiler has no edge to cross. These three
          -- commands grep that single seam; <leader>go (outgoing calls) descends
          -- the rest via the TS LSP call hierarchy. Searches run from the git root
          -- and degrade gracefully outside covenant-web's resolvers/gql layout.
          local function flow_git_root()
            local out = vim.fn.systemlist('git rev-parse --show-toplevel')
            if vim.v.shell_error ~= 0 then return nil end
            return out[1]
          end

          -- Run ripgrep --vimgrep, return quickfix-shaped items.
          local function flow_rg(root, args)
            local cmd = { 'rg', '--vimgrep', '--color=never', '--no-heading' }
            vim.list_extend(cmd, args)
            local res = vim.system(cmd, { cwd = root, text = true }):wait()
            local items = {}
            for _, line in ipairs(vim.split(res.stdout or "", '\n', { trimempty = true })) do
              local file, lnum, col, text = line:match('^(.-):(%d+):(%d+):(.*)$')
              if file then
                items[#items + 1] = {
                  filename = root .. '/' .. file,
                  lnum = tonumber(lnum),
                  col = tonumber(col),
                  text = text,
                }
              end
            end
            return items
          end

          -- 0 → notify; 1 → jump straight there; many → quickfix + Trouble list.
          local function flow_go(items, what)
            if #items == 0 then
              vim.notify('flow: no ' .. what, vim.log.levels.WARN)
            elseif #items == 1 then
              local it = items[1]
              vim.cmd('edit ' .. vim.fn.fnameescape(it.filename))
              vim.api.nvim_win_set_cursor(0, { it.lnum, math.max(it.col - 1, 0) })
            else
              vim.fn.setqflist({}, ' ', { title = 'flow: ' .. what, items = items })
              vim.cmd('Trouble qflist open focus=true')
            end
          end

          local function flow_cword() return vim.fn.expand('<cword>') end

          -- gql field under cursor → its resolver implementation.
          vim.api.nvim_create_user_command('FlowResolver', function()
            local root = flow_git_root(); if not root then return end
            local f = flow_cword()
            -- Repo convention: `<field>: combineResolvers(` or `<field>: (async )(`.
            local items = flow_rg(root, {
              '-g', '**/resolvers/**/*.ts', '-g', '!**/*.test.*',
              '-e', '^\\s*' .. f .. '\\s*:\\s*(combineResolvers|async|\\()',
            })
            if #items == 0 then -- fallback: method-shorthand resolver field
              items = flow_rg(root, { '-g', '**/resolvers/**/*.ts', '-g', '!**/*.test.*',
                '-e', '^\\s*' .. f .. '\\s*\\(' })
            end
            flow_go(items, 'resolver for `' .. f .. '`')
          end, { desc = 'GraphQL field under cursor → resolver' })

          -- field/operation under cursor → frontend gql documents that select it.
          vim.api.nvim_create_user_command('FlowUsages', function()
            local root = flow_git_root(); if not root then return end
            local f = flow_cword()
            local items = flow_rg(root, {
              '-g', '**/gql/**/*.{ts,tsx}', '-g', '**/*queries*.{ts,tsx}', '-g', '**/*.graphql',
              '-e', '\\b' .. f .. '\\b',
            })
            flow_go(items, 'frontend usages of `' .. f .. '`')
          end, { desc = 'GraphQL field under cursor → frontend usages' })

          -- field under cursor → its definition in the schema SDL.
          vim.api.nvim_create_user_command('FlowSchema', function()
            local root = flow_git_root(); if not root then return end
            local f = flow_cword()
            local items = flow_rg(root, {
              '-g', '**/tmp/*.graphql', '-g', '**/schema/**/*.{graphql,ts}',
              '-e', '^\\s*' .. f .. '\\s*[(:]',
            })
            flow_go(items, 'schema definition of `' .. f .. '`')
          end, { desc = 'GraphQL field under cursor → schema SDL definition' })

          -- Is the cursor inside an injected graphql region? The ecma injection
          -- query (inherited by typescript/tsx) tags gql`` template bodies as
          -- 'graphql', so treesitter answers this directly.
          local function flow_in_graphql()
            if vim.bo.filetype == 'graphql' then return true end
            local ok, parser = pcall(vim.treesitter.get_parser)
            if not ok or not parser then return false end
            local row, col = unpack(vim.api.nvim_win_get_cursor(0))
            local ok2, lt = pcall(function()
              return parser:language_for_range({ row - 1, col, row - 1, col })
            end)
            return ok2 and lt ~= nil and lt:lang() == 'graphql'
          end

          -- Reuse the standard LSP keys: inside a gql`` block they cross the wire,
          -- otherwise they're the plain LSP action. Nothing new to remember.
          local function flow_smart(graphql_cmd, lsp_fn)
            return function()
              if flow_in_graphql() then vim.cmd(graphql_cmd) else lsp_fn() end
            end
          end
          vim.keymap.set('n', 'gd', flow_smart('FlowSchema', vim.lsp.buf.definition),
            { silent = true, desc = 'Definition (→ schema SDL in gql``)' })
          vim.keymap.set('n', 'gri', flow_smart('FlowResolver', vim.lsp.buf.implementation),
            { silent = true, desc = 'Implementation (→ resolver in gql``)' })
          vim.keymap.set('n', 'grr', flow_smart('FlowUsages', vim.lsp.buf.references),
            { silent = true, desc = 'References (→ frontend usages in gql``)' })

          -- ─── Branch review (no diff view — lazygit owns diffs) ────────────────
          -- Two surfaces, both anchored to main: a Trouble list of changed files
          -- (<leader>gc) and gitsigns gutter marks (+/~/-) for every line that
          -- differs from main, expandable inline with <leader>hp. <leader>gc sets
          -- the gutter base too, so "review this branch vs main" is one keypress.

          -- gitsigns gutter base: nil = index (normal "since last commit" feedback);
          -- merge-base with main = whole-branch view (committed changes included,
          -- matching the three-dot `main...HEAD` the file list uses). On main itself
          -- the merge-base is HEAD, so setting it is a harmless no-op.
          local branch_base = nil
          local function set_branch_base(on)
            local gs = require('gitsigns')
            if not on then
              gs.change_base(nil, true)
              branch_base = nil
              return true
            end
            local root = flow_git_root(); if not root then return false end
            local mb = vim.fn.systemlist('git -C ' .. root .. ' merge-base main HEAD')[1]
            if not mb or mb == "" then
              vim.notify('branch base: no merge-base with main', vim.log.levels.WARN)
              return false
            end
            gs.change_base(mb, true)
            branch_base = mb
            return true
          end

          -- Changed files on this branch (three-dot vs main) → flat Trouble list,
          -- and align the gutter to main in the same keypress.
          vim.api.nvim_create_user_command('ChangedFiles', function()
            local root = flow_git_root(); if not root then return end
            local files = vim.fn.systemlist('git -C ' .. root .. ' diff --name-only main...HEAD')
            if vim.v.shell_error ~= 0 then
              vim.notify('ChangedFiles: git diff failed', vim.log.levels.WARN); return
            end
            set_branch_base(true)
            local items = {}
            for _, f in ipairs(files) do
              items[#items + 1] = { filename = root .. '/' .. f, lnum = 1, col = 1, text = f }
            end
            if #items == 0 then
              vim.notify('No changes vs main', vim.log.levels.INFO); return
            end
            vim.fn.setqflist({}, ' ', { title = 'Changed vs main', items = items })
            -- One item per file (line 1), so skip the per-file group header and the
            -- meaningless [1,1] position — render a flat list of filenames.
            require('trouble').open({
              mode = 'qflist',
              focus = true,
              groups = {},
              format = '{file_icon} {filename}',
            })
          end, { desc = 'Branch changed files vs main → Trouble (+ gutter vs main)' })

          -- Toggle the gutter base between index and main without opening the list.
          vim.api.nvim_create_user_command('BranchSigns', function()
            if branch_base then
              set_branch_base(false)
              vim.notify('gitsigns: base = index')
            elseif set_branch_base(true) then
              vim.notify('gitsigns: base = main (' .. branch_base:sub(1, 8) .. ')')
            end
          end, { desc = 'Toggle gitsigns base: index ↔ main merge-base' })

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
