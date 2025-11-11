local config_module = require("blink-cmp-fuzzy-path.config")
local file_search = require("blink-cmp-fuzzy-path.file_search")

local Source = {}
Source.__index = Source

-- Constructor
function Source:new(opts)
  opts = opts or {}
  local config = config_module.setup(opts)

  local self = setmetatable({
    config = config,
  }, Source)

  return self
end

-- Check if source should be enabled for current buffer
function Source:enabled()
  return vim.tbl_contains(self.config.filetypes, vim.bo.filetype)
end

-- Return trigger characters
function Source:get_trigger_characters()
  return { self.config.trigger_char }
end

-- Extract query string after trigger character
local function extract_query(line, trigger_char, cursor_col)
  cursor_col = cursor_col or #line
  local trigger_pos = nil

  -- Find the last occurrence of trigger character before cursor
  for i = cursor_col, 1, -1 do
    if line:sub(i, i) == trigger_char then
      trigger_pos = i
      break
    end
  end

  if not trigger_pos then
    return nil
  end

  -- Extract query (everything after trigger up to cursor)
  local query = line:sub(trigger_pos + 1, cursor_col - 1)
  return query
end

-- Main completion function
function Source:get_completions(ctx, callback)
  local trigger_char = self.config.trigger_char
  local line = ctx.line or ""
  local cursor_col = ctx.col or #line + 1

  -- Extract query after trigger character
  local query = extract_query(line, trigger_char, cursor_col)

  -- If no trigger found or query extraction failed, return empty
  if not query then
    callback({ items = {} })
    return
  end

  -- Get current buffer path for relative path calculation
  local bufpath = vim.api.nvim_buf_get_name(ctx.bufnr or 0)

  -- Perform file search (synchronous for MVP)
  local files = file_search.search_files(query, self.config, bufpath)

  -- Convert to completion items
  local items = {}
  for index, file in ipairs(files) do
    table.insert(items, {
      label = file,
      kind = vim.lsp.protocol.CompletionItemKind.File,
      insertText = file,
      filterText = file,
      sortText = string.format("%03d", index),
    })
  end

  -- Call callback with results
  callback({
    items = items,
    is_incomplete_forward = true,  -- Refetch as user types more
    is_incomplete_backward = true, -- Refetch as user deletes characters
  })
end

-- Setup function for lazy.nvim
local function setup(user_config)
  -- This is called during plugin initialization
  -- The actual source instance is created by blink.cmp
  return Source:new(user_config)
end

-- Export
return {
  new = function(opts)
    return Source:new(opts)
  end,
  setup = setup,
}
