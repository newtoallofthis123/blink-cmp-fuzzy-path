local M = {}

-- Check if a command exists
local function command_exists(cmd)
	return vim.fn.executable(cmd) == 1
end

-- Make path relative to current buffer's directory
local function make_relative_path(filepath, bufpath, search_base)
	if not bufpath or bufpath == "" then
		return filepath
	end

	-- Use search_base if provided, otherwise fall back to cwd
	-- Expand ~ and normalize the base directory
	local base_dir = search_base or vim.fn.getcwd()
	base_dir = vim.fn.expand(base_dir)
	base_dir = vim.fn.fnamemodify(base_dir, ":p")
	-- Remove trailing slash
	if vim.endswith(base_dir, "/") then
		base_dir = base_dir:sub(1, -2)
	end

	local buf_dir = vim.fn.fnamemodify(bufpath, ":h")
	local abs_filepath = vim.fn.fnamemodify(filepath, ":p")

	-- If filepath is already relative, make it absolute first using the search base directory
	if not vim.startswith(filepath, "/") then
		abs_filepath = vim.fn.fnamemodify(base_dir .. "/" .. filepath, ":p")
	end

	-- Check if file is within buffer's directory
	if vim.startswith(abs_filepath, buf_dir) then
		-- Calculate relative path from buffer directory
		local rel_path = vim.fn.fnamemodify(abs_filepath, ":.")
		return rel_path
	end

	-- Return path relative to the search base directory
	-- Remove the base_dir prefix to get just the relative portion
	if vim.startswith(abs_filepath, base_dir .. "/") then
		return abs_filepath:sub(#base_dir + 2) -- +2 to skip the trailing "/"
	end

	-- Fallback to relative to cwd (with ~ expansion)
	return vim.fn.fnamemodify(abs_filepath, ":~:.")
end

-- Search files using fd (async)
local function search_with_fd_async(query, config, callback)
	if not command_exists("fd") then
		callback({})
		return nil
	end

	local args = { "--type", "f" }

	if config.search_hidden then
		table.insert(args, "--hidden")
	end

	-- Respect gitignore by default (don't use --no-ignore)
	-- If search_gitignore is false, ignore gitignore files
	if not config.search_gitignore then
		table.insert(args, "--no-ignore")
	end

	table.insert(args, "--max-results")
	table.insert(args, tostring(config.max_results))

	-- Add query as pattern
	if query and query ~= "" then
		table.insert(args, query)
	end

	-- Determine search path
	local search_path = "."
	if config.search_dir and config.search_dir ~= "" then
		search_path = config.search_dir
	end

	local stdout = vim.loop.new_pipe(false)
	local handle, pid
	local results = {}
	local stdout_data = ""

	handle, pid = vim.loop.spawn(
		"fd",
		{
			args = args,
			stdio = { nil, stdout, nil },
			cwd = search_path,
		},
		vim.schedule_wrap(function(code, signal)
			stdout:close()
			if handle and not handle:is_closing() then
				handle:close()
			end

			-- Process any remaining data
			if stdout_data ~= "" then
				for line in stdout_data:gmatch("([^\n]+)") do
					if line ~= "" then
						table.insert(results, line)
					end
				end
			end

			callback(results)
		end)
	)

	if not handle then
		callback({})
		return nil
	end

	stdout:read_start(vim.schedule_wrap(function(err, data)
		if err then
			callback({})
			return
		end

		if data then
			stdout_data = stdout_data .. data
		end
	end))

	-- Return cancellation function
	return function()
		if handle and not handle:is_closing() then
			handle:close()
		end
		if stdout and not stdout:is_closing() then
			stdout:close()
		end
	end
end

-- Search files using ripgrep (async)
local function search_with_rg_async(query, config, callback)
	if not command_exists("rg") then
		callback({})
		return nil
	end

	-- First get all files, then filter with query
	local args = { "--files" }

	if config.search_hidden then
		table.insert(args, "--hidden")
	end

	if not config.search_gitignore then
		table.insert(args, "--no-ignore")
	end

	-- Determine search path
	local search_path = "."
	if config.search_dir and config.search_dir ~= "" then
		search_path = config.search_dir
	end

	local stdout = vim.loop.new_pipe(false)
	local handle, pid
	local all_files = {}
	local stdout_data = ""

	handle, pid = vim.loop.spawn(
		"rg",
		{
			args = args,
			stdio = { nil, stdout, nil },
			cwd = search_path,
		},
		vim.schedule_wrap(function(code, signal)
			stdout:close()
			if handle and not handle:is_closing() then
				handle:close()
			end

			-- Process any remaining data
			if stdout_data ~= "" then
				for line in stdout_data:gmatch("([^\n]+)") do
					if line ~= "" then
						table.insert(all_files, line)
					end
				end
			end

			-- Filter files by query if provided
			local results = {}
			if query and query ~= "" then
				for _, file in ipairs(all_files) do
					if string.find(file:lower(), query:lower(), 1, true) then
						table.insert(results, file)
						if #results >= config.max_results then
							break
						end
					end
				end
			else
				-- Return limited results if no query
				for i = 1, math.min(#all_files, config.max_results) do
					table.insert(results, all_files[i])
				end
			end

			callback(results)
		end)
	)

	if not handle then
		callback({})
		return nil
	end

	stdout:read_start(vim.schedule_wrap(function(err, data)
		if err then
			callback({})
			return
		end

		if data then
			stdout_data = stdout_data .. data
		end
	end))

	-- Return cancellation function
	return function()
		if handle and not handle:is_closing() then
			handle:close()
		end
		if stdout and not stdout:is_closing() then
			stdout:close()
		end
	end
end

-- Main search function (async)
function M.search_files_async(query, config, bufpath, callback)
	local search_func

	if config.search_tool == "fd" then
		search_func = search_with_fd_async
	elseif config.search_tool == "rg" then
		search_func = search_with_rg_async
	else
		-- Auto-detect: prefer fd, fallback to rg
		if command_exists("fd") then
			search_func = search_with_fd_async
		elseif command_exists("rg") then
			search_func = search_with_rg_async
		else
			vim.notify("blink-cmp-fuzzy-path: Neither 'fd' nor 'rg' found. Please install one.", vim.log.levels.WARN)
			callback({})
			return nil
		end
	end

	-- Call search function and wrap callback to handle relative paths
	local cancel_fn = search_func(query, config, function(files)
		-- Convert to relative paths if configured
		if config.relative_paths and bufpath then
			-- Determine the search base directory
			local search_base = config.search_dir or vim.fn.getcwd()
			files = vim.tbl_map(function(file)
				return make_relative_path(file, bufpath, search_base)
			end, files)
		end

		callback(files)
	end)

	return cancel_fn
end

return M
