local M = {}

-- Default configuration
local defaults = {
	filetypes = { "markdown", "json" },
	trigger_char = "@",
	max_results = 5,
	search_tool = "fd", -- 'fd' or 'rg'
	search_hidden = false,
	search_gitignore = true,
	relative_paths = true,
	search_dir = nil, -- nil = use cwd, string = specific directory
	include_folders = false, -- include folders in search results
}

-- Validate configuration
local function validate_config(config)
	vim.validate({
		filetypes = { config.filetypes, "table" },
		trigger_char = { config.trigger_char, "string" },
		max_results = { config.max_results, "number" },
		search_tool = { config.search_tool, "string" },
		search_hidden = { config.search_hidden, "boolean" },
		search_gitignore = { config.search_gitignore, "boolean" },
		relative_paths = { config.relative_paths, "boolean" },
		include_folders = { config.include_folders, "boolean" },
		search_dir = {
			config.search_dir,
			function(v)
				return v == nil or type(v) == "string"
			end,
			"nil or string",
		},
	})

	-- Validate trigger_char is a single character
	if #config.trigger_char ~= 1 then
		error("trigger_char must be a single character")
	end

	-- Validate search_tool
	if config.search_tool ~= "fd" and config.search_tool ~= "rg" then
		error("search_tool must be 'fd' or 'rg'")
	end

	-- Validate max_results is positive
	if config.max_results < 1 then
		error("max_results must be at least 1")
	end

	-- Validate search_dir if provided
	if config.search_dir ~= nil and config.search_dir ~= "" then
		local expanded = vim.fn.expand(config.search_dir)
		local abs_path = vim.fn.fnamemodify(expanded, ":p")

		if vim.fn.isdirectory(abs_path) ~= 1 then
			error(string.format("search_dir '%s' is not a valid directory", config.search_dir))
		end

		-- Normalize to absolute path
		config.search_dir = abs_path
	end
end

-- Merge user config with defaults
function M.setup(user_config)
	user_config = user_config or {}
	local config = vim.tbl_deep_extend("force", defaults, user_config)
	validate_config(config)
	return config
end

return M
