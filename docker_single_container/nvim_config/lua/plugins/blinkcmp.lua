return {
	"saghen/blink.cmp",
	dependencies = {
		"rafamadriz/friendly-snippets",
		"giuxtaposition/blink-cmp-copilot",
	},
	version = "*",
	opts = {
		keymap = { preset = "default" },

		sources = {
			default = { "lsp", "path", "snippets", "buffer", "copilot" },
			providers = {
				--[[ lazydev = {
					name = "LazyDev",
					module = "lazydev.integrations.blink",
					-- make lazydev completions top priority (see `:h blink.cmp`)
					score_offset = 100,
				}, ]]
				copilot = {
					name = "copilot",
					module = "blink-cmp-copilot",
					score_offset = 100,
					async = true,
					transform_items = function(_, items)
						local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
						local kind_idx = #CompletionItemKind + 1
						CompletionItemKind[kind_idx] = "Copilot"
						for _, item in ipairs(items) do
							item.kind = kind_idx
						end
						return items
					end,
				},
			},
		},
		appearance = {
			use_nvim_cmp_as_default = true,
			nerd_font_variant = "mono",
			-- Blink does not expose its default kind icons so you must copy them all (or set your custom ones) and add Copilot
			kind_icons = {
				Copilot = "",
				Text = "󰉿",
				Method = "󰊕",
				Function = "󰊕",
				Constructor = "󰒓",

				Field = "󰜢",
				Variable = "󰆦",
				Property = "󰖷",

				Class = "󱡠",
				Interface = "󱡠",
				Struct = "󱡠",
				Module = "󰅩",

				Unit = "󰪚",
				Value = "󰦨",
				Enum = "󰦨",
				EnumMember = "󰦨",

				Keyword = "󰻾",
				Constant = "󰏿",

				Snippet = "󱄽",
				Color = "󰏘",
				File = "󰈔",
				Reference = "󰬲",
				Folder = "󰉋",
				Event = "󱐋",
				Operator = "󰪚",
				TypeParameter = "󰬛",
			},
		},

		cmdline = {
			completion = {
				ghost_text = {
					enabled = true,
				},
			},
		},

		signature = {
			enabled = true,
			window = {
				border = "rounded",
			},
		},

		completion = {

			keyword = {
				range = "full",
			},

			list = {
				selection = {
					preselect = false,
					auto_insert = true,
				},
			},

			accept = {
				auto_brackets = {
					enabled = true,
				},
			},

			menu = {
				min_width = math.min(40, vim.o.columns),
				border = "rounded",
				draw = {
					columns = { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "source" } },
					components = {
						source = {
							text = function(ctx)
								local map = {
									["lsp"] = "[]",
									["path"] = "[]",
									["snippets"] = "[]",
								}

								return map[ctx.item.source_id]
							end,
							highlight = "BlinkCmpDoc",
						},
					},
				},
			},

			documentation = {
				auto_show = true,
				auto_show_delay_ms = 100,
				update_delay_ms = 50,
				window = {
					min_width = 10,
					max_width = math.min(80, vim.o.columns),
					border = "rounded",
				},
			},
		},
	},
	opts_extend = { "sources.default" },
}
