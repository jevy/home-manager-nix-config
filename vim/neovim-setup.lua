vim.opt.mouse = "a"
vim.opt.compatible = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.swapfile = false
vim.opt.incsearch = true
vim.opt.listchars = { tab = ">-", trail = "-" }
vim.opt.number = true
vim.opt.scrolloff = 5
vim.opt.showmatch = true
vim.opt.ignorecase = true
-- vim.opt.autochdir = true
vim.opt.wildmode = { "list", "longest" }
vim.opt.linebreak = true
vim.opt.relativenumber = true

if vim.fn.has("termguicolors") == 1 then
	vim.opt.termguicolors = true
end
vim.opt.background = "dark"

vim.g.gruvbox_material_background = "soft"
vim.g.gruvbox_material_better_performance = 0
vim.cmd.colorscheme("gruvbox-material")

vim.opt.updatetime = 100
vim.opt.smartindent = true
vim.opt.autoindent = true
-- vim.cmd("filetype indent on")
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.softtabstop = 2
vim.opt.wrap = false

vim.opt.splitbelow = true

vim.g.mapleader = " "

-- Highlight trailing whitespace
vim.cmd([[
  highlight ExtraWhitespace ctermbg=red guibg=red
  match ExtraWhitespace /\s\+$/
  autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
  autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
  autocmd InsertLeave * match ExtraWhitespace /\s\+$/
  autocmd BufWinLeave * call clearmatches()
  autocmd Syntax * syn match ExtraWhitespace /\s\+$\| \+\ze\t/
]])

-- Map keys
-- vim.api.nvim_set_keymap("n", "gd", ":Gvdiffsplit<CR>", { noremap = true, silent = true })

-- Spell check in Latex
vim.cmd([[
  augroup latexsettings
    autocmd!
    autocmd FileType tex set spell
  augroup END
]])

-- Autocommands
vim.cmd([[
  augroup HiglightTODO
    autocmd!
    autocmd WinEnter,VimEnter * :silent! call matchadd('Todo', 'TODO', -1)
  augroup END

  augroup AutoAdjustResize
    autocmd!
    autocmd VimResized * execute "normal! \<C-w>="
  augroup END

  augroup lsp_install
    au!
    autocmd User lsp_buffer_enabled call s:on_lsp_buffer_enabled()
  augroup END

  autocmd CursorHold .notes :write
]])

-- Nvim-tree setup
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.termguicolors = true
require("nvim-tree").setup({
	view = {
		width = 60,
	},
	renderer = {
		group_empty = true,
	},
	filters = {
		dotfiles = true,
	},
	update_focused_file = {
		enable = true,
		update_cwd = true,
	},
})
vim.api.nvim_set_keymap("n", "<C-n>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-f>", ":Telescope find_files<CR>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<C-g>", ":Telescope live_grep<CR>", { noremap = true, silent = true })

require("leap").add_default_mappings()

-- require("treesitter-context").setup({
--   enable = true,
--   max_lines = 0,
--   min_window_height = 0,
--   line_numbers = true,
-- })

require("nvim-treesitter.configs").setup({
	textobjects = {
		select = {
			enable = true,
			lookahead = true,
			keymaps = {
				["af"] = "@function.outer",
				["if"] = "@function.inner",
				["ap"] = "@parameter.outer",
				["ip"] = "@parameter.inner",
				["ac"] = "@comment.outer",
			},
			include_surrounding_whitespace = false,
		},
		swap = {
			enable = true,
		},
		move = {
			enable = true,
			goto_next_start = {
				["]f"] = "@function.outer",
				["]p"] = "@parameter.outer",
			},
			goto_next_end = {
				["]F"] = "@function.outer",
			},
			goto_previous_start = {
				["[f"] = "@function.outer",
				["[p"] = "@parameter.outer",
			},
			goto_previous_end = {
				["[F"] = "@function.outer",
			},
			goto_next = {
				["]d"] = "@conditional.outer",
			},
			goto_previous = {
				["[d"] = "@conditional.outer",
			},
		},
		highlight = {
			enable = true,
		},
		indent = {
			enable = true,
		},
		lsp_interop = {
			enable = true,
			border = "none",
			floating_preview_opts = {},
			peek_definition_code = {
				["<leader>df"] = "@function.outer",
				["<leader>dF"] = "@class.outer",
			},
		},
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<Leader>ss", -- set to `false` to disable one of the mappings
			node_incremental = "<Leader>sm",
			scope_incremental = "<Leader>sc",
			node_decremental = "<Leader>sr",
		},
	},
})

-- Repeat movement with ; and ,
local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")
vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move)
vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_opposite)

vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = "v:lua.vim.treesitter.foldtext()"

require("nvim-treesitter.configs").setup({
	textobjects = {
		select = {
			enable = true,

			lookahead = true,
			include_surrounding_whitespace = true,
		},
		move = {
			enable = true,
		},
	},
})

-- Indent blank line
-- Integrate with rainbow-delimeters
local highlight = {
	"RainbowRed",
	"RainbowYellow",
	"RainbowBlue",
	"RainbowOrange",
	"RainbowGreen",
	"RainbowViolet",
	"RainbowCyan",
}
local hooks = require("ibl.hooks")
-- create the highlight groups in the highlight setup hook, so they are reset
-- every time the colorscheme changes
hooks.register(hooks.type.HIGHLIGHT_SETUP, function()
	vim.api.nvim_set_hl(0, "RainbowRed", { fg = "#E06C75" })
	vim.api.nvim_set_hl(0, "RainbowYellow", { fg = "#E5C07B" })
	vim.api.nvim_set_hl(0, "RainbowBlue", { fg = "#61AFEF" })
	vim.api.nvim_set_hl(0, "RainbowOrange", { fg = "#D19A66" })
	vim.api.nvim_set_hl(0, "RainbowGreen", { fg = "#98C379" })
	vim.api.nvim_set_hl(0, "RainbowViolet", { fg = "#C678DD" })
	vim.api.nvim_set_hl(0, "RainbowCyan", { fg = "#56B6C2" })
end)

vim.g.rainbow_delimiters = { highlight = highlight }
require("ibl").setup({ scope = { highlight = highlight } })

hooks.register(hooks.type.SCOPE_HIGHLIGHT, hooks.builtin.scope_highlight_from_extmark)

-- Completion
local cmp = require("cmp")
cmp.setup({
	snippet = {
		expand = function(args)
			vim.fn["UltiSnips#Anon"](args.body)
		end,
	},
	window = {
		completion = cmp.config.window.bordered(),
		documentation = cmp.config.window.bordered(),
	},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-Space>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<CR>"] = cmp.mapping.confirm({ select = true }),
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "ultisnips" },
	}, {
		{ name = "buffer" },
	}),
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Typescript LSP
require("lspconfig").tsserver.setup({
	capabilities = capabilities,
	init_options = {
		plugins = {
			{
				location = "shouldbeautofound",
				languages = { "javascript", "typescript", "typescriptreact" },
			},
		},
	},
	filetypes = {
		"javascript",
		"typescript",
		"typescriptreact",
	},
})

-- Nix LSP
require("lspconfig").nil_ls.setup({
	capabilities = capabilities,
})

-- Ruby LSP
require("lspconfig").solargraph.setup({
  capabilities = capabilities,
  filetypes = {
    "ruby",
  },
})

-- Lua/Vim LSP
require("lspconfig").lua_ls.setup({
	settings = {
		Lua = {
			diagnostics = {
				globals = { "vim" },
			},
		},
	},
})

-- Terraform LSP
require("lspconfig").terraformls.setup({})
vim.api.nvim_create_autocmd({ "BufWritePre" }, {
	pattern = { "*.tf", "*.tfvars" },
	callback = function()
		vim.lsp.buf.format()
	end,
})

-- require("lspsaga").setup({
--   move_in_saga = {
--     prev = "<C-k>",
--     next = "<C-j>",
--   },
--   finder_action_keys = {
--     open = "<CR>",
--   },
--   definition_action_keys = {
--     edit = "<CR>",
--   },
-- })
-- Formatting
require("lspconfig").efm.setup({
	init_options = {
		documentFormatting = true,
		documentRangeFormatting = true,
		hover = true,
		documentSymbol = true,
		codeAction = true,
		completion = true,
	},
	settings = {
		rootMarkers = { ".git/" },
		languages = {
			lua = {
				-- require("efmls-configs.linters.luacheck"),
				require("efmls-configs.formatters.stylua"),
			},
			nix = {
				require("efmls-configs.formatters.alejandra"),
			},
			typescript = {
				require("efmls-configs.linters.eslint"),
				require("efmls-configs.formatters.eslint"),
			},
		},
	},
})

-- auto-format on save
local lsp_fmt_group = vim.api.nvim_create_augroup("LspFormattingGroup", {})
vim.api.nvim_create_autocmd("BufWritePre", {
	group = lsp_fmt_group,
	callback = function()
		local efm = vim.lsp.get_active_clients({ name = "efm" })

		if vim.tbl_isempty(efm) then
			return
		end

		vim.lsp.buf.format({ name = "efm" })
	end,
})

local wk = require("which-key")
