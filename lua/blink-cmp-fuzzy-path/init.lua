local config_module = require("blink-cmp-fuzzy-path.config")
local file_search = require("blink-cmp-fuzzy-path.file_search")

-- Keep track of the global source instance for command access
local _global_source = nil

-- Shared search_dir across all instances
local _shared_search_dir = nil

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

	-- Use shared search_dir if set, otherwise use instance config
	local config = vim.tbl_extend("force", self.config, {})
	if _shared_search_dir ~= nil then
		config.search_dir = _shared_search_dir
	end

	-- Perform file search (async)
	local cancel_fn = file_search.search_files_async(query, config, bufpath, function(files)
		-- Convert to completion items
		local items = {}
		for index, file in ipairs(files) do
			-- Determine if this is a folder (has trailing slash)
			local is_folder = vim.endswith(file, "/")
			local kind = is_folder and vim.lsp.protocol.CompletionItemKind.Folder
				or vim.lsp.protocol.CompletionItemKind.File

			local item = {
				label = file,
				kind = kind,
				insertText = file,
				filterText = file,
				-- Use lower sortText values to prioritize these results
				-- Format: "0000", "0001", "0002" ensures they sort before most other sources
				sortText = string.format("%04d", index),
				score_offset = 5, -- Boost score for this source
			}
			
			-- Add documentation to make folders more visible in completion menu
			if is_folder then
				item.documentation = {
					kind = "markdown",
					value = "📁 Directory",
				}
			end
			
			table.insert(items, item)
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

-- Set the search directory for this source instance
function Source:set_path(path)
	-- Validate that path exists and is a directory
	if not path or path == "" then
		_shared_search_dir = nil
		self.config.search_dir = nil
		return true
	end

	-- Expand path (handle ~, ., .., etc.)
	local expanded_path = vim.fn.expand(path)
	local abs_path = vim.fn.fnamemodify(expanded_path, ":p")

	-- Check if path exists
	if vim.fn.isdirectory(abs_path) ~= 1 then
		vim.notify(
			string.format("fuzzy-path: '%s' is not a valid directory", path),
			vim.log.levels.ERROR
		)
		return false
	end

	-- Update shared search_dir and instance config
	_shared_search_dir = abs_path
	self.config.search_dir = abs_path

	vim.notify(
		string.format("fuzzy-path: Search directory set to '%s'", abs_path),
		vim.log.levels.INFO
	)

	return true
end

-- Get current search directory
function Source:get_path()
	return _shared_search_dir or self.config.search_dir or vim.fn.getcwd()
end

-- Public API function to set search path
local function set_path(path)
	if not _global_source then
		vim.notify(
			"fuzzy-path: Plugin not initialized. Call setup() first.",
			vim.log.levels.ERROR
		)
		return false
	end
	return _global_source:set_path(path)
end

-- Public API function to get current search path
local function get_path()
	return _shared_search_dir or vim.fn.getcwd()
end

-- Setup function for lazy.nvim
local function setup(user_config)
	-- Create and store the global source instance
	_global_source = Source:new(user_config)

	-- Register command
	vim.api.nvim_create_user_command("FuzzySearchPath", function(opts)
		local path = opts.args

		-- If no argument provided, show current path
		if not path or path == "" then
			local current_path = get_path()
			vim.notify(
				string.format("Current fuzzy search directory: %s", current_path),
				vim.log.levels.INFO
			)
			return
		end

		-- Set the new path
		set_path(path)
	end, {
		nargs = "?", -- Optional argument
		complete = "dir", -- Directory completion
		desc = "Set or display the fuzzy file search directory",
	})

	return _global_source
end

-- Export
return {
	new = function(opts)
		return Source:new(opts)
	end,
	setup = setup,
	set_path = set_path,
	get_path = get_path,
}
