# blink-cmp-fuzzy-path

A Neovim plugin that provides fuzzy file path completion for [blink.cmp](https://github.com/saghen/blink.cmp). Type `@` (or a custom trigger) in configured filetypes to get intelligent file path suggestions.

## Features

- 🎯 **Fuzzy file path completion** - Type `@` followed by a query to find files
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
        }
      }
    }
  }
}
```

## Configuration

Default configuration:

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

### Example: Custom Configuration

```lua
{
  'newtoallofthis123/blink-cmp-fuzzy-path',
  opts = {
    filetypes = { "markdown", "json", "text" },
    trigger_char = "#",
    max_results = 10,
    search_tool = "rg",
    search_hidden = true,
    relative_paths = true,
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

Typing `@read` will show suggestions like:
- `README.md`
- `docs/readme.md`
- `src/readers/file_reader.lua`

## How It Works

1. **Trigger Detection**: When you type the trigger character (`@` by default), the plugin activates
2. **Query Extraction**: Everything after `@` up to your cursor becomes the search query
3. **File Search**: Uses `fd` or `ripgrep` to find files matching your query
4. **Path Formatting**: Converts absolute paths to relative paths (if configured)
5. **Completion**: Shows results in the blink.cmp completion menu

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
