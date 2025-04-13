return {
  "stevearc/conform.nvim",
  event = { "BufReadPre", "BufNewFile" },
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      haskell = { "fourmolu" },
      html = { "prettierd" },
      css = { "prettierd" },
      scss = { "prettierd" },
      javascript = { "prettierd" },
      typescript = { "prettierd" },
      json = { "jq" },
      toml = { "taplo" },
      bash = { "beautysh" },
      ksh = { "beautysh" },
      sh = { "beautysh" },
      python = { "black" },
    },
    format_on_save = {
      timout_ms = 500,
      lsp_fallback = true,
    },
  },
}
