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

	-- Extract everything after trigger up to cursor
	local text_after_trigger = line:sub(trigger_pos + 1, cursor_col - 1)

	-- Find first space to limit query to one word
	local space_pos = text_after_trigger:find(" ")
	if space_pos then
		return text_after_trigger:sub(1, space_pos - 1)
	else
		return text_after_trigger
	end
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

	-- Perform file search (async)
	local cancel_fn = file_search.search_files_async(query, self.config, bufpath, function(files)
		-- Convert to completion items
		local items = {}
		for index, file in ipairs(files) do
			table.insert(items, {
				label = file,
				kind = vim.lsp.protocol.CompletionItemKind.File,
				insertText = file,
				filterText = file,
				-- Use lower sortText values to prioritize these results
				-- Format: "0000", "0001", "0002" ensures they sort before most other sources
				sortText = string.format("%04d", index),
				score_offset = 5, -- Boost score for this source
			})
		end

		-- Call callback with results
		callback({
			items = items,
			is_incomplete_forward = true, -- Refetch as user types more
			is_incomplete_backward = true, -- Refetch as user deletes characters
		})
	end)

	-- Return cancellation function so blink.cmp can cancel if user types quickly
	return cancel_fn
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
