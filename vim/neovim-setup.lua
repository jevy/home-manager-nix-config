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

-- Set wrap for markdown and Avante files
vim.cmd([[
  augroup MarkdownWrap
    autocmd!
    autocmd FileType markdown setlocal wrap
  augroup END
]])

-- Autocommands
-- Highlight TODO
vim.api.nvim_create_augroup("HighlightTODO", { clear = true })
vim.api.nvim_create_autocmd({ "WinEnter", "VimEnter" }, {
	group = "HighlightTODO",
	pattern = "*",
	callback = function()
		vim.fn.matchadd("Todo", "TODO", -1)
	end,
})

-- Auto-adjust window size on resize
vim.api.nvim_create_augroup("AutoAdjustResize", { clear = true })
vim.api.nvim_create_autocmd("VimResized", {
	group = "AutoAdjustResize",
	pattern = "*",
	command = "wincmd =",
})

-- LSP installation
vim.api.nvim_create_augroup("LspInstall", { clear = true })
vim.api.nvim_create_autocmd("User", {
	group = "LspInstall",
	pattern = "lsp_buffer_enabled",
	callback = function()
		-- Replace this with the actual function you want to call
		-- vim.fn['s:on_lsp_buffer_enabled']()
		print("LSP buffer enabled")
	end,
})

-- Auto-save notes
vim.api.nvim_create_augroup("AutoSaveNotes", { clear = true })
vim.api.nvim_create_autocmd("CursorHold", {
	group = "AutoSaveNotes",
	pattern = "*.notes",
	command = "write",
})

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

-- Define the on_attach function
local on_attach = function(client, bufnr)
	-- Enable completion triggered by <c-x><c-o>
	vim.api.nvim_buf_set_option(bufnr, "omnifunc", "v:lua.vim.lsp.omnifunc")

	-- Define key mappings
	local opts = { noremap = true, silent = true, buffer = bufnr }

	-- LSP Keybindings
	vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
	vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
	vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
	vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
	vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
	vim.keymap.set("n", "<leader>wa", vim.lsp.buf.add_workspace_folder, opts)
	vim.keymap.set("n", "<leader>wr", vim.lsp.buf.remove_workspace_folder, opts)
	vim.keymap.set("n", "<leader>wl", function()
		print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
	end, opts)
	vim.keymap.set("n", "<leader>D", vim.lsp.buf.type_definition, opts)
	vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
	vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
	vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
	vim.keymap.set("n", "<leader>e", vim.diagnostic.open_float, opts)
	vim.keymap.set("n", "[d", vim.diagnostic.goto_prev, opts)
	vim.keymap.set("n", "]d", vim.diagnostic.goto_next, opts)
	vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, opts)
end

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

-- Snippets

local ls = require("luasnip")
require("luasnip.loaders.from_vscode").lazy_load()

vim.keymap.set({ "i" }, "<C-K>", function()
	ls.expand()
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-L>", function()
	ls.jump(1)
end, { silent = true })
vim.keymap.set({ "i", "s" }, "<C-J>", function()
	ls.jump(-1)
end, { silent = true })

vim.keymap.set({ "i", "s" }, "<C-E>", function()
	if ls.choice_active() then
		ls.change_choice(1)
	end
end, { silent = true })

-- Completion

local cmp = require("cmp")

cmp.setup({
	snippet = {
		expand = function(args)
			require("luasnip").lsp_expand(args.body)
			-- vim.snippet.expand(args.body)
		end,
	},
	mapping = cmp.mapping.preset.insert({
		["<C-b>"] = cmp.mapping.scroll_docs(-4),
		["<C-f>"] = cmp.mapping.scroll_docs(4),
		["<C-o>"] = cmp.mapping.complete(),
		["<C-e>"] = cmp.mapping.abort(),
		["<Tab>"] = cmp.mapping.confirm({ select = true }),
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "luasnip" },
	}, {
		{ name = "buffer" },
	}),
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Typescript LSP
require("lspconfig").ts_ls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
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
	on_attach = on_attach,
})

-- Language Server
require("lspconfig").ltex.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	settings = {
		ltex = {
			language = "en-CA",
			disabledRules = { ["en-CA"] = { "MORFOLOGIK_RULE_EN_CA" } },
		},
	},
})

vim.keymap.set("n", "<leader>aw", function()
	vim.lsp.buf.execute_command({
		command = "_ltex.addToDictionary",
		arguments = {
			{
				uri = vim.uri_from_bufnr(0),
				words = {
					["en-CA"] = { vim.fn.expand("<cword>") },
				},
			},
		},
	})
end, { desc = "Add word to dictionary" })

-- Ruby LSP
require("lspconfig").solargraph.setup({
	capabilities = capabilities,
	on_attach = on_attach,
	filetypes = {
		"ruby",
	},
})

-- Lua/Vim LSP
require("lspconfig").lua_ls.setup({
	capabilities = capabilities,
	on_attach = on_attach,
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

require("avante_lib").load()
require("avante").setup({
	provider = "claude",
	auto_suggestions_provider = "claude",
	claude = {
		endpoint = "https://api.anthropic.com",
		model = "claude-3-5-sonnet-20240620",
		temperature = 0,
		max_tokens = 4096,
	},
	mappings = {
		suggestion = {
			accept = "<M-l>",
			next = "<M-]>",
			prev = "<M-[>",
			dismiss = "<C-]>",
		},
	},
})

local wk = require("which-key")

-- Markview configuration
local markview_filetypes = { "markdown", "vimwiki", "Avante" }
require("markview").setup({
	ft = markview_filetypes,
	opts = {
		filetypes = markview_filetypes,
	},
})

require("trouble").setup({
	group = true,
	padding = true,
	action_keys = {
		close = "q",
		cancel = "<esc>",
		next = "j",
		previous = "k",
	},
})

-- Add keymaps for Trouble
vim.keymap.set(
	"n",
	"<leader>xx",
	"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
	{ desc = "Buffer Diagnostics (Trouble)" }
)
vim.keymap.set("n", "<leader>cs", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Symbols (Trouble)" })
vim.keymap.set(
	"n",
	"<leader>cl",
	"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
	{ desc = "LSP Definitions / references / ... (Trouble)" }
)
