-- Nvim-tree
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

require("treesitter-context").setup({
	enable = true,
	max_lines = 0,
	min_window_height = 0,
	line_numbers = true,
})

require("nvim-treesitter.configs").setup({
	textobjects = {
		select = {
			enable = true,
			lookahead = true,
		},
		swap = {
			enable = true,
		},
		move = {
			enable = true,
		},
	},
})

require("ibl").setup()

local cmp = require("cmp")
cmp.setup({
	snippet = {
		-- REQUIRED - you must specify a snippet engine
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
		["<CR>"] = cmp.mapping.confirm({ select = true }), -- Accept currently selected item. Set `select` to `false` to only confirm explicitly selected items.
	}),
	sources = cmp.config.sources({
		{ name = "nvim_lsp" },
		{ name = "ultisnips" },
	}, {
		{ name = "buffer" },
	}),
})

local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- LSPs
--
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
-- 	move_in_saga = {
-- 		prev = "<C-k>",
-- 		next = "<C-j>",
-- 	},
-- 	finder_action_keys = {
-- 		open = "<CR>",
-- 	},
-- 	definition_action_keys = {
-- 		edit = "<CR>",
-- 	},
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
				require("efmls-configs.linters.luacheck"),
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
wk.register(mappings, opts)
