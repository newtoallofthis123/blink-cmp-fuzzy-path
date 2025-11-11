# Fuzzy Path Plugin Implementation Plan

## Overview
Create a Neovim plugin that integrates with blink.cmp to provide fuzzy file path completion when typing `@` (or a custom trigger character) in specified filetypes.

## Plugin Name
`blink-cmp-fuzzy-path` (following blink.cmp naming convention)

---

## 1. Project Structure

```
blink-cmp-fuzzy-path/
├── lua/
│   └── blink-cmp-fuzzy-path/
│       ├── init.lua          # Main module & blink.cmp source implementation
│       ├── config.lua         # Configuration management
│       └── file_search.lua    # File search logic using ripgrep/fd
├── README.md
└── LICENSE
```

---

## 2. Configuration & Setup

### Default Configuration
```lua
{
  filetypes = { "markdown", "json" },    -- Filetypes to attach to
  trigger_char = "@",                     -- Character that triggers completion
  max_results = 5,                        -- Number of results to show
  search_tool = "fd",                     -- 'fd' or 'rg' (ripgrep)
  search_hidden = false,                  -- Include hidden files
  search_gitignore = true,                -- Respect .gitignore
  relative_paths = true,                  -- Show relative paths from current buffer
}
```

### Setup Function
The plugin should expose a `setup()` function that:
- Validates user configuration using `vim.validate()`
- Merges user config with defaults
- Stores configuration for use by the source

---

## 3. Blink.cmp Source Implementation

### 3.1 Source Structure (`lua/blink-cmp-fuzzy-path/init.lua`)

The source must implement the following blink.cmp API:

#### **`new(opts)`** - Constructor
- Receives options from blink.cmp provider config
- Validates options (filetypes, trigger_char, max_results)
- Initializes file search module
- Returns source instance

#### **`enabled()`** - Activation Control
- Check if current buffer's filetype matches configured filetypes
- Return `true` only for specified filetypes
```lua
function Source:enabled()
  return vim.tbl_contains(self.config.filetypes, vim.bo.filetype)
end
```

#### **`get_trigger_characters()`** - Trigger Definition
- Return array containing the trigger character(s)
```lua
function Source:get_trigger_characters()
  return { self.config.trigger_char }
end
```

#### **`get_completions(ctx, callback)`** - Core Completion Logic
This is the heart of the plugin. It must:

1. **Extract the query string** after the trigger character:
   - Parse `ctx.line` to find the trigger char position
   - Extract everything after `@` up to cursor position
   - Example: `"See @hello"` → query = `"hello"`

2. **Handle empty queries gracefully**:
   - If query is empty (just typed `@`), optionally show recent files or all files
   - Or wait for at least 1-2 characters before searching

3. **Perform async file search**:
   - Call file search module with the query string
   - Use ripgrep or fd to fuzzy match file paths
   - Limit results to `max_results`

4. **Convert file paths to completion items**:
   ```lua
   {
     label = "relative/path/to/file.md",
     kind = vim.lsp.protocol.CompletionItemKind.File,
     insertText = "relative/path/to/file.md",
     filterText = "relative/path/to/file.md",
     sortText = string.format("%03d", index),
   }
   ```

5. **Handle relative paths**:
   - Calculate path relative to current buffer's directory
   - Use `vim.fn.fnamemodify()` for path manipulation

6. **Call the callback**:
   - Must call `callback({ items = completion_items })` when done
   - Set `is_incomplete_forward = false` (don't refetch on typing)
   - Set `is_incomplete_backward = false` (don't refetch on deletion)

7. **Return cancellation function** (optional):
   - If search is async, return a function that can cancel the job
   - Important for performance when user types quickly

---

## 4. File Search Module (`lua/blink-cmp-fuzzy-path/file_search.lua`)

### 4.1 Search Tool Selection

Support both `fd` and `rg` (ripgrep):

**Using `fd` (recommended for file listing):**
```bash
fd --type f --max-results 5 "query"
```

**Using `rg` (alternative):**
```bash
rg --files | rg "query"
```

### 4.2 Implementation Options

#### Option A: Synchronous with `vim.fn.systemlist()` (Simple)
```lua
local function search_files_sync(query, max_results)
  local cmd = string.format('fd --type f --max-results %d "%s"', max_results, query)
  local files = vim.fn.systemlist(cmd)
  return files
end
```

**Pros:** Simple, no dependencies
**Cons:** Can block Neovim UI on slow filesystems

#### Option B: Async with `vim.loop` (Recommended)
```lua
local function search_files_async(query, max_results, callback)
  local stdout = vim.loop.new_pipe(false)
  local handle, pid

  handle, pid = vim.loop.spawn('fd', {
    args = { '--type', 'f', '--max-results', tostring(max_results), query },
    stdio = { nil, stdout, nil }
  }, vim.schedule_wrap(function(code, signal)
    stdout:close()
    handle:close()
  end))

  local results = {}
  stdout:read_start(vim.schedule_wrap(function(err, data)
    if data then
      for line in data:gmatch("[^\n]+") do
        table.insert(results, line)
      end
    else
      callback(results)
    end
  end))

  -- Return cancellation function
  return function()
    if handle then
      handle:close()
    end
  end
end
```

**Pros:** Non-blocking, professional approach
**Cons:** More complex code

#### Option C: Using Plenary.nvim (Optional Dependency)
If user has plenary installed, use `plenary.job`:
```lua
local Job = require('plenary.job')

local function search_files_plenary(query, max_results, callback)
  local job = Job:new({
    command = 'fd',
    args = { '--type', 'f', '--max-results', tostring(max_results), query },
    on_exit = vim.schedule_wrap(function(j, return_val)
      callback(j:result())
    end),
  })

  job:start()

  return function()
    job:shutdown()
  end
end
```

**Recommendation:** Start with Option A (synchronous) for MVP, then add Option B for production use.

### 4.3 Path Manipulation

Calculate relative paths from current buffer:
```lua
local function make_relative_path(filepath, bufpath)
  local buf_dir = vim.fn.fnamemodify(bufpath, ':h')
  local rel_path = vim.fn.fnamemodify(filepath, ':~:.')

  -- Calculate relative from buffer's directory
  if vim.startswith(filepath, buf_dir) then
    rel_path = vim.fn.fnamemodify(filepath, ':.')
  end

  return rel_path
end
```

---

## 5. Lazy.nvim Installation

Users should be able to install with:

```lua
{
  'newtoallofthis123/blink-cmp-fuzzy-path',
  dependencies = { 'saghen/blink.cmp' },
  opts = {
    filetypes = { "markdown", "json" },
    trigger_char = "@",
    max_results = 5,
  }
}
```

Then register it with blink.cmp:

```lua
{
  'saghen/blink.cmp',
  opts = {
    sources = {
      default = { 'lsp', 'path', 'snippets', 'buffer', 'fuzzy-path' },
      providers = {
        ['fuzzy-path'] = {
          name = 'Fuzzy Path',
          module = 'blink-cmp-fuzzy-path',
          score_offset = 0,  -- Adjust priority if needed
        }
      }
    }
  }
}
```

---

## 6. Implementation Steps

### Phase 1: MVP (Synchronous Search)
1. **Create project structure**
   - Set up directory tree
   - Create initial Lua files

2. **Implement config module** (`config.lua`)
   - Define default config
   - Create merge function
   - Add validation

3. **Implement basic file search** (`file_search.lua`)
   - Use `vim.fn.systemlist()` with `fd` or `rg`
   - Handle errors gracefully
   - Return array of file paths

4. **Implement blink.cmp source** (`init.lua`)
   - Create `new()` constructor
   - Implement `enabled()` for filetype checking
   - Implement `get_trigger_characters()`
   - Implement basic `get_completions()`:
     - Parse trigger and query
     - Call file search
     - Convert to completion items
     - Call callback

5. **Test manually**
   - Install locally using lazy.nvim
   - Test in markdown file
   - Verify `@` triggers completion
   - Verify file paths appear

### Phase 2: Async & Polish
6. **Add async file search**
   - Implement using `vim.loop.spawn()`
   - Return cancellation function
   - Handle rapid typing gracefully

7. **Add advanced features**
   - Relative path calculation from buffer
   - Search tool detection (auto-detect fd or rg)
   - Configurable search options (hidden files, gitignore)

8. **Error handling & edge cases**
   - Handle missing fd/rg gracefully
   - Handle empty query
   - Handle no results found
   - Add user-friendly error messages

### Phase 3: Documentation & Release
9. **Write comprehensive README**
   - Installation instructions
   - Configuration examples
   - Screenshots/demos
   - Troubleshooting

10. **Add health check** (optional)
    - Create `health.lua` in `lua/blink-cmp-fuzzy-path/`
    - Check if fd or rg is installed
    - Verify configuration is valid

---

## 7. Testing Strategy

### Manual Testing Checklist
- [ ] Plugin loads without errors
- [ ] `@` triggers completion in markdown files
- [ ] `@` does NOT trigger in non-configured filetypes
- [ ] File paths appear in completion menu
- [ ] Selecting a completion inserts the file path
- [ ] Fuzzy matching works (`@mdfile` matches `some/markdown_file.md`)
- [ ] Max results limit is respected
- [ ] Custom trigger character works
- [ ] Custom filetypes work
- [ ] Relative paths are correct

### Edge Cases
- [ ] Empty query (just `@`)
- [ ] No matching files
- [ ] Very large repositories (performance)
- [ ] Missing fd/rg binary
- [ ] Invalid configuration

---

## 8. Dependencies

### Required
- **Neovim** ≥ 0.9.0 (for modern Lua APIs)
- **blink.cmp** (the completion plugin)
- **fd** or **ripgrep** (system binaries for file search)

### Optional
- **plenary.nvim** (for alternative async implementation)

---

## 9. Key References

### Blink.cmp Documentation
- Source Boilerplate: https://cmp.saghen.dev/development/source-boilerplate.html
- Configuration: https://cmp.saghen.dev/

### Community Examples
- blink-cmp-git: https://github.com/Kaiser-Yang/blink-cmp-git
- Other blink.cmp sources for reference patterns

### Neovim Lua APIs
- `vim.fn.systemlist()` - Synchronous command execution
- `vim.loop.spawn()` - Async process spawning
- `vim.schedule_wrap()` - Safe callback execution
- `vim.fn.fnamemodify()` - Path manipulation
- `vim.bo.filetype` - Current buffer filetype

### Tools
- **fd**: Modern find replacement (https://github.com/sharkdp/fd)
- **ripgrep**: Fast grep alternative (https://github.com/BurntSushi/ripgrep)

---

## 10. Success Criteria

The plugin will be considered successful when:

1. ✅ User types `@` in a markdown file
2. ✅ Autocomplete menu appears with file paths
3. ✅ Typing after `@` filters results (e.g., `@read` shows `README.md`)
4. ✅ Selecting a completion inserts the relative file path
5. ✅ Works seamlessly with other blink.cmp sources
6. ✅ No noticeable performance impact or UI blocking
7. ✅ Easy to install via lazy.nvim
8. ✅ Configurable for different use cases

---

## 11. Future Enhancements (Post-MVP)

- **Smart context detection**: Auto-detect when user is writing links/references
- **File preview**: Show file preview in completion documentation
- **Custom formatters**: Allow users to format inserted paths (e.g., markdown links `[label](path)`)
- **Multi-trigger support**: Different triggers for different search scopes (e.g., `@` for local, `@@` for global)
- **Cache frequently used paths**: Performance optimization
- **Integration with telescope**: Use telescope's fuzzy finder for complex queries

---

## Notes

- Focus on **simplicity** for MVP - get it working with synchronous search first
- **Async is critical** for production - don't block the UI
- **Good defaults** matter - it should work well out of the box for markdown users
- Follow **blink.cmp conventions** - makes integration seamless
- **Minimal dependencies** - only require what's absolutely necessary
