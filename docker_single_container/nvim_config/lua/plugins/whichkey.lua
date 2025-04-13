-- Which-Key.nvim configuration
-- This plugin displays a popup with possible key bindings of the command you started typing
return {
	"folke/which-key.nvim", -- Plugin repository
	event = "VeryLazy", -- Load plugin on VeryLazy event for better startup performance
	opts = {}, -- Use default options for which-key
	keys = {
		{
			"<leader>?", -- Key mapping to show keybindings for the current buffer
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer Local Keymaps (which-key)", -- Description shown in which-key popup
		},
	},
	config = function()
		local wk = require("which-key")
		wk.add({
			{
				"<leader>cci",
				function()
					local input = vim.fn.input("Ask Copilot: ")
					if input ~= "" then
						vim.cmd("CopilotChat " .. input)
					end
				end,
				desc = "CopilotChat - Ask input",
			},

			{
				mode = { "n", "v" },

				-- BUFFER NAVIGATION
				-- Keys for navigating between buffers using BufferLine
				{ "<leader>bn", "<cmd>BufferLineCycleNext<cr>", desc = "Next Buffer" },
				{ "<leader>bp", "<cmd>BufferLineCyclePrev<cr>", desc = "Previous Buffer" },
				{ "<leader>bmn", "<cmd>BufferLineMoveNext<cr>", desc = "Move Buffer (forwards)" },
				{ "<leader>bmp", "<cmd>BufferLineMovePrev<cr>", desc = "Move Buffer (backwards)" },

				-- FILE EXPLORER
				-- Keys for managing the oil.nvim file explorer
				{ "<leader>oo", "<cmd>Oil --float --preview<cr>", desc = "Open Oil" },
				{ "<leader>oq", "<cmd>lua require('oil').close()<cr>", desc = "Close Oil" },

				-- COPILOT CHAT COMMANDS
				-- Keys for interacting with Copilot Chat
				{ "<leader>ccc", "<cmd>CopilotChatToggle<cr>", desc = "Toggle Copilot Chat" },
				{ "<leader>ccs", "<cmd>CopilotChatStop<cr>", desc = "Stop Copilot Chat" },
				{ "<leader>ccr", "<cmd>CopilotChatReset<cr>", desc = "Reset Copilot Chat" },
				{ "<leader>ccv", "<cmd>CopilotChatSave<cr>", desc = "Save Copilot Chat" },
				{ "<leader>ccl", "<cmd>CopilotChatLoad<cr>", desc = "Load Copilot Chat" },
				{ "<leader>ccp", "<cmd>CopilotChatPrompts<cr>", desc = "View Copilot Chat Prompts" },
				{ "<leader>ccm", "<cmd>CopilotChatModels<cr>", desc = "View Copilot Chat Models" },
				{ "<leader>cca", "<cmd>CopilotChatAgents<cr>", desc = "View Copilot Chat Agents" },
				{ "<leader>ccq", "<cmd>CopilotChatPrompt<cr>", desc = "Prompt Copilot Chat" },
				{ "<leader>ccw", "<cmd>CopilotChatReview<cr>", desc = "Review Copilot Chat" },
				{ "<leader>ccf", "<cmd>CopilotChatFix<cr>", desc = "Fix Copilot Chat" },
				{ "<leader>cco", "<cmd>CopilotChatOptimize<cr>", desc = "Optimize Copilot Chat" },
				{ "<leader>ccd", "<cmd>CopilotChatDocs<cr>", desc = "Docs Copilot Chat" },
				{ "<leader>cct", "<cmd>CopilotChatTests<cr>", desc = "Tests Copilot Chat" },
				{
					"<leader>cci",
					function()
						local input = vim.fn.input("Ask Copilot: ")
						if input ~= "" then
							vim.cmd("CopilotChat " .. input)
						end
					end,
					desc = "CopilotChat - Ask input",
				},
			},
		})
	end,
}
