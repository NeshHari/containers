return {
	"catppuccin/nvim",
	lazy = false,
	name = "catppuccin",
	config = function()
		require("catppuccin").setup({
			flavour = "mocha",
			transparent_background = false,
			integrations = {
				treesitter = true,
				treesitter_context = true,
				native_lsp = {
					enabled = true,
					virtual_text = {
						errors = { "italic" },
						hints = { "italic" },
						warnings = { "italic" },
						information = { "italic" },
					},
					underlines = {
						errors = { "underline" },
						hints = { "underline" },
						warnings = { "underline" },
						information = { "underline" },
					},
					inlay_hints = {
						background = true,
					},
				},
				lsp_saga = true,
				dap = true,
				dap_ui = true,
				telescope = true,
				indent_blankline = {
					enabled = true,
					colored_indent_levels = true,
				},
				rainbow_delimiters = true,
				noice = true,
				notify = true,
				notifier = true,
				flash = true,
				cmp = true,
				blink_cmp = true,
				nvim_surround = true,
				render_markdown = true,
				which_key = true,
			},
			highlight = {
				enabled = true,
				additional_vim_regex_highlighting = true,
			},
			custom_highlights = function(colors)
				return {
					BlinkCmpMenu = { bg = colors.base },
					BlinkCmpMenuBorder = { fg = colors.flamingo },
					BlinkCmpMenuSelection = { bg = colors.green, fg = colors.base },
					BlinkCmpScrollBarThumb = { bg = colors.flamingo },
					BlinkCmpGhostText = { fg = colors.surface2 },
					BlinkCmpLabel = { fg = colors.subtext0 },
					BlinkCmpLabelMatch = { fg = colors.green },
					BlinkCmpDocBorder = { fg = colors.mauve },
				}
			end,
		})
		vim.cmd.colorscheme("catppuccin")
	end,
}
