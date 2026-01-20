# blink-cmp-fuzzy-path

A Neovim plugin that provides fuzzy file path completion for [blink.cmp](https://github.com/saghen/blink.cmp). Type `@` (or a custom trigger) in configured filetypes to get intelligent file path suggestions.

https://github.com/user-attachments/assets/dec72195-7088-4afd-b282-f77c8f880e42


## Features

- 🎯 **Fuzzy file path completion** - Type `@` followed by a query to find files
- 📁 **Optional folder search** - Include directories in search results (disabled by default)
- 📝 **Filetype-specific** - Only activates in configured filetypes (default: markdown, json)
- 🔍 **Fast search** - Uses `fd` or `ripgrep` for blazing-fast file discovery
- 📍 **Relative paths** - Shows paths relative to your current buffer
- ⚙️ **Highly configurable** - Customize trigger character, filetypes, search options, and more

## Requirements

- **Neovim** ≥ 0.9.0
- **blink.cmp** - The completion framework
- **fd** or **ripgrep** - At least one must be installed on your system
  - [fd](https://github.com/sharkdp/fd) (recommended)
  - [ripgrep](https://github.com/BurntSushi/ripgrep)

## Installation

### Using lazy.nvim

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
      default = {  'fuzzy-path', 'lsp', 'path', 'snippets', 'buffer',},
      providers = {
        ['fuzzy-path'] = {
          name = 'Fuzzy Path',
          module = 'blink-cmp-fuzzy-path',
          score_offset = 0,
          -- Optional: Configure the source here
          opts = {
            include_folders = false,  -- Set to true to include folders in results
            max_results = 5,
          },
        }
      }
    }
  }
}
```

> **Note:** You can configure the plugin either in the lazy.nvim `opts` (shown above in Installation) OR in the blink.cmp provider `opts`. The provider configuration takes precedence.

## Configuration

Default configuration:

```lua
{
  filetypes = { "markdown", "json" },    -- Filetypes to attach to
  trigger_char = "@",                     -- Character that triggers completion
  max_results = 5,                        -- Number of results to show (files + folders combined)
  search_tool = "fd",                     -- 'fd' or 'rg' (ripgrep)
  search_hidden = false,                  -- Include hidden files/folders
  search_gitignore = true,                -- Respect .gitignore
  relative_paths = true,                  -- Show relative paths from current buffer
  include_folders = false,                -- Include folders in search results
}
```

### Folder Search

By default, only files are shown in completion results. To include folders in search results, set `include_folders = true`:

```lua
{
  'newtoallofthis123/blink-cmp-fuzzy-path',
  opts = {
    include_folders = true,  -- Enable folder search
    max_results = 10,        -- Increase to show more files + folders
  }
}
```

Or configure it in the blink.cmp provider:

```lua
{
  'saghen/blink.cmp',
  opts = {
    sources = {
      providers = {
        ['fuzzy-path'] = {
          name = 'Fuzzy Path',
          module = 'blink-cmp-fuzzy-path',
          opts = {
            include_folders = true,  -- Enable folder search
            max_results = 10,
          },
        }
      }
    }
  }
}
```

**Important Notes:**
- 📁 Folders are displayed with a trailing `/` (e.g., `src/`, `docs/`)
- 📊 Folders appear before files in the completion list for easier navigation
- 🔧 With `fd` tool: Full folder search support (recommended)
- ⚠️  With `ripgrep`: Requires `fd` to be installed for folder search (shows a warning if not available)
- 🔢 The `max_results` limit applies to the combined total of files and folders
- 🔄 After changing the config, restart Neovim or run `:Lazy reload blink-cmp-fuzzy-path`

### Important: ClaudeCode and OpenCode Users

⚠️ **Latest versions of ClaudeCode and OpenCode** open Neovim in their own configuration directories, not your project root. This means fuzzy path searches will start from the wrong location.

**Solution**: Use the `:FuzzySearchPath` command to set the correct search directory:

```vim
:FuzzySearchPath /path/to/your/project
```

You can automate this with a telescope-based directory picker or keybinding:

```lua
-- Example: Set up a keybinding to pick directory with Telescope
vim.keymap.set('n', '<leader>fp', function()
  require('telescope.builtin').find_files({
    prompt_title = 'Set Fuzzy Search Path',
    cwd = vim.fn.getcwd(),
    attach_mappings = function(prompt_bufnr, map)
      local actions = require('telescope.actions')
      local action_state = require('telescope.actions.state')

      map('i', '<CR>', function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local dir = vim.fn.fnamemodify(selection.path, ':h')
        vim.cmd('FuzzySearchPath ' .. dir)
      end)
      return true
    end,
  })
end, { desc = 'Set fuzzy search path' })
```

### Example: Custom Configuration

```lua
{
  'newtoallofthis123/blink-cmp-fuzzy-path',
  opts = {
    filetypes = { "markdown", "json", "text" },
    trigger_char = "#",
    max_results = 10,
    search_tool = "fd",        -- Use fd for best performance
    search_hidden = true,      -- Include hidden files/folders
    relative_paths = true,
    include_folders = true,    -- Enable folder search
  }
}
```

## Usage

1. Open a file in a configured filetype (e.g., `markdown`)
2. Type `@` followed by part of a filename
3. Completion menu appears with matching file paths
4. Select a path to insert it

### Example

In a markdown file:
```
See @read
```

**With `include_folders = false` (default):**
Typing `@read` will show file suggestions like:
- `README.md`
- `docs/readme.md`
- `src/readers/file_reader.lua`

**With `include_folders = true`:**
Typing `@read` will show both folders and files:
- `src/readers/` (📁 folder)
- `README.md`
- `docs/readme.md`
- `src/readers/file_reader.lua`

## How It Works

1. **Trigger Detection**: When you type the trigger character (`@` by default), the plugin activates
2. **Query Extraction**: Everything after `@` up to your cursor becomes the search query
3. **File/Folder Search**: Uses `fd` or `ripgrep` to find files (and optionally folders) matching your query
4. **Path Formatting**: Converts absolute paths to relative paths (if configured)
5. **Completion**: Shows results in the blink.cmp completion menu with appropriate icons (files vs folders)

## Troubleshooting

### No completions appearing

- **Check filetype**: Make sure your current buffer's filetype is in the configured `filetypes` list
- **Check trigger**: Ensure you're typing the correct trigger character (default: `@`)
- **Check tools**: Verify that `fd` or `rg` is installed and available in your PATH:
  ```bash
  which fd
  # or
  which rg
  ```

### Slow performance

- Use `fd` instead of `rg` for better file search performance
- Reduce `max_results` to limit the number of files searched
- Ensure `.gitignore` is being respected (set `search_gitignore = true`)

### Wrong paths

- If paths are too long, check `relative_paths` setting
- Paths are calculated relative to your current buffer's directory

## Development

### Project Structure

```
blink-cmp-fuzzy-path/
├── lua/
│   └── blink-cmp-fuzzy-path/
│       ├── init.lua          # Main module & blink.cmp source
│       ├── config.lua         # Configuration management
│       └── file_search.lua    # File search logic
├── README.md
└── LICENSE
```

## License

MIT License - see LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Acknowledgments

- [blink.cmp](https://github.com/saghen/blink.cmp) - The completion framework
- [fd](https://github.com/sharkdp/fd) - Fast file finder
- [ripgrep](https://github.com/BurntSushi/ripgrep) - Fast grep alternative
