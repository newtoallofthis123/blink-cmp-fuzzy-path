local M = {}

-- Check if a command exists
local function command_exists(cmd)
  return vim.fn.executable(cmd) == 1
end

-- Make path relative to current buffer's directory
local function make_relative_path(filepath, bufpath)
  if not bufpath or bufpath == "" then
    return filepath
  end

  local buf_dir = vim.fn.fnamemodify(bufpath, ":h")
  local abs_filepath = vim.fn.fnamemodify(filepath, ":p")

  -- If filepath is already relative, make it absolute first
  if not vim.startswith(filepath, "/") then
    abs_filepath = vim.fn.fnamemodify(vim.fn.getcwd() .. "/" .. filepath, ":p")
  end

  -- Check if file is within buffer's directory
  if vim.startswith(abs_filepath, buf_dir) then
    -- Calculate relative path from buffer directory
    local rel_path = vim.fn.fnamemodify(abs_filepath, ":.")
    return rel_path
  end

  -- Otherwise return relative to cwd
  return vim.fn.fnamemodify(abs_filepath, ":~:.")
end

-- Search files using fd (synchronous)
local function search_with_fd(query, config)
  if not command_exists("fd") then
    return {}
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

  local cmd = "fd " .. table.concat(vim.tbl_map(function(arg)
    return vim.fn.shellescape(arg)
  end, args), " ")

  local files = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return {}
  end

  return files
end

-- Search files using ripgrep (synchronous)
local function search_with_rg(query, config)
  if not command_exists("rg") then
    return {}
  end

  -- First get all files, then filter with query
  local args = { "--files" }

  if config.search_hidden then
    table.insert(args, "--hidden")
  end

  if not config.search_gitignore then
    table.insert(args, "--no-ignore")
  end

  local cmd = "rg " .. table.concat(vim.tbl_map(function(arg)
    return vim.fn.shellescape(arg)
  end, args), " ")

  local all_files = vim.fn.systemlist(cmd)
  if vim.v.shell_error ~= 0 then
    return {}
  end

  -- Filter files by query if provided
  if query and query ~= "" then
    local filtered = {}
    for _, file in ipairs(all_files) do
      if string.find(file:lower(), query:lower(), 1, true) then
        table.insert(filtered, file)
        if #filtered >= config.max_results then
          break
        end
      end
    end
    return filtered
  end

  -- Return limited results if no query
  return vim.list_slice(all_files, 1, config.max_results)
end

-- Main search function
function M.search_files(query, config, bufpath)
  local files = {}

  if config.search_tool == "fd" then
    files = search_with_fd(query, config)
  elseif config.search_tool == "rg" then
    files = search_with_rg(query, config)
  else
    -- Auto-detect: prefer fd, fallback to rg
    if command_exists("fd") then
      files = search_with_fd(query, config)
    elseif command_exists("rg") then
      files = search_with_rg(query, config)
    else
      vim.notify("blink-cmp-fuzzy-path: Neither 'fd' nor 'rg' found. Please install one.", vim.log.levels.WARN)
      return {}
    end
  end

  -- Convert to relative paths if configured
  if config.relative_paths and bufpath then
    files = vim.tbl_map(function(file)
      return make_relative_path(file, bufpath)
    end, files)
  end

  return files
end

return M
