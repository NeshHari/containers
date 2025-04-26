local custom_colors = {
	rosewater = "#f5e0dc",
	flamingo = "#f2cdcd",
	pink = "#f5c2e7",
	mauve = "#cba6f7",
	red = "#f38ba8",
	maroon = "#eba0ac",
	peach = "#fab387",
	yellow = "#f9e2af",
	green = "#a6e3a1",
	teal = "#94e2d5",
	sky = "#89dceb",
	sapphire = "#74c7ec",
	blue = "#89b4fa",
	lavender = "#b4befe",
	text = "#cdd6f4",
	subtext1 = "#bac2de",
	subtext0 = "#a6adc8",
	overlay2 = "#9399b2",
	overlay1 = "#7f849c",
	overlay0 = "#6c7086",
	surface2 = "#585b70",
	surface1 = "#45475a",
	surface0 = "#313244",
	base = "#1e1e2e",
	mantle = "#181825",
	crust = "#11111b",
}

return {
	"nvim-lualine/lualine.nvim",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		require("lualine").setup({
			options = {
				icons_enabled = true,
				theme = "catppuccin",
				component_separators = {},
				section_separators = { left = "", right = "" },
				disabled_filetypes = {
					statusline = {},
					winbar = {},
				},
				color = { bg = custom_colors.base },
				ignore_focus = {},
				always_divide_middle = true,
				always_show_tabline = true,
				globalstatus = false,
				refresh = {
					statusline = 100,
					-- tabline = 100,
					-- winbar = 100,
				},
			},
			sections = {
				lualine_a = {
					{
						"filetype",
						padding = { left = 0, right = 1 },
						separator = { left = "", right = "" },
						color = {
							fg = custom_colors.base,
							bg = custom_colors.teal,
							gui = "italic,bold",
						},
					},
					{
						"lsp_status",
						padding = { left = 1, right = 0 },
						separator = { left = "", right = "" },
						color = {
							fg = custom_colors.base,
							bg = custom_colors.blue,
							gui = "italic,bold",
						},
					},
				},
				lualine_b = {
					{
						"selectioncount",
						padding = { left = 1, right = 0 },
						separator = { left = "", right = "" },
						color = {
							fg = custom_colors.base,
							bg = custom_colors.mauve,
							gui = "bold",
						},
						icon = {
							"",
							align = "left",
							color = {
								fg = custom_colors.base,
								bg = custom_colors.mauve,
								gui = "bold",
							},
						},
					},
					{
						"diagnostics",
						padding = { left = 1, right = 0 },
						-- separator = { left = "", right = "" },
						color = {
							bg = custom_colors.base,
							gui = "bold",
						},
					},
				},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {
					{
						"searchcount",
						padding = { left = 0, right = 1 },
						separator = { left = "", right = "" },
						color = {
							fg = custom_colors.base,
							bg = custom_colors.yellow,
							gui = "bold",
						},
						icon = {
							"",
							align = "left",
							color = {
								fg = custom_colors.base,
								bg = custom_colors.yellow,
								gui = "bold",
							},
						},
					},
					{
						"progress",
						padding = { left = 0, right = 1 },
						separator = { left = "", right = "" },
						color = {
							fg = custom_colors.base,
							bg = custom_colors.flamingo,
							gui = "bold",
						},
						icon = {
							"  ",
							align = "left",
							color = {
								fg = custom_colors.flamingo,
								bg = custom_colors.base,
								gui = "bold",
							},
						},
					},
				},
				lualine_z = {
					{
						"mode",
						separator = { left = "", right = "" },
						padding = { left = 1, right = 0 },
						color = {
							fg = custom_colors.base,
							bg = custom_colors.red,
							gui = "bold",
						},
						icon = {
							" ",
							align = "left",
							color = {
								fg = custom_colors.red,
								bg = custom_colors.base,
							},
						},
					},
				},
			},
			inactive_sections = {
				lualine_a = {},
				lualine_b = {},
				lualine_c = {},
				lualine_x = {},
				lualine_y = {},
				lualine_z = {},
			},
			tabline = {},
			winbar = {},
			inactive_winbar = {},
			extensions = {},
		})
	end,
}
