---@module 'blink.cmp'
local api = require("copilot.api")
local format = require("blink-cmp-copilot.format")
local util = require("copilot.util")

--- @class blink-cmp-copilot.Source : blink.cmp.Source
--- @field client vim.lsp.Client | nil
local M = {}

local function set_client()
  require("copilot")
  local clients = vim.lsp.get_clients({
    name = "copilot",
  })
  M.client = clients[1]
end

function M.get_trigger_characters()
  return { "." }
end

function M:enabled()
  set_client()
  return M.client ~= nil
end

function M:get_completions(context, callback)
  local respond_callback = function(err, response)
    if err or not response or not response.completions then
      return callback({
        is_incomplete_forward = true,
        is_incomplete_backward = true,
        items = {},
      })
    end

    local items = vim.tbl_map(function(item)
      return format.format_item(item, context)
    end, vim.tbl_values(response.completions))

    return callback({
      is_incomplete_forward = false,
      is_incomplete_backward = false,
      items = items,
    })
  end

  api.get_completions(M.client, util.get_doc_params(), respond_callback)
end

function M:new()
  set_client()
  return setmetatable({}, { __index = M })
end

return M
