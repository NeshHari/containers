return {
	"catgoose/nvim-colorizer.lua",
	event = "BufReadPre",
	opts = {
		user_default_options = {
			names = false, -- "Name" codes like Blue or red.  Added from `vim.api.nvim_get_color_map()`
		},
	},
}
