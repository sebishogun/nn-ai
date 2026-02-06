# 99 - AI Code Generation for Neovim

Fork of [ThePrimeagen/99](https://github.com/ThePrimeagen/99) with multi-provider support.

## What's Different in This Fork

- **Multi-provider support**: OpenCode, Claude Code, GitHub Copilot CLI, Gemini CLI, Codex CLI
- **Latest models**: claude-opus-4-6, gpt-codex-5.3, gemini-3-pro-preview
- **Additional language support**: Rust, Python, Zig, TypeScript (+ original Lua, Go, Java, etc.)
- **Improved prompts**: Language-aware prompts with explicit "no markdown fences" instructions
- **Provider switching**: Switch between AI providers on the fly with `:NN*` commands

## Supported Providers

| Provider | CLI Command | Default Model | Install |
|----------|-------------|---------------|---------|
| OpenCode | `opencode` | claude-opus-4-6 | `curl -fsSL https://opencode.ai/install \| bash` |
| Claude Code | `claude` | claude-opus-4-6 | `npm install -g @anthropic-ai/claude-code` |
| Copilot CLI | `copilot` | claude-opus-4.6 | `curl -fsSL https://gh.io/copilot-install \| bash` |
| Gemini CLI | `gemini` | gemini-3-pro-preview | `npm install -g @google/gemini-cli` |
| Codex CLI | `codex` | gpt-codex-5.3 | `npm install -g @openai/codex` |

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "sebishogun/99",
    config = function()
        local _99 = require("99")
        
        _99.setup({
            -- Logger configuration
            logger = {
                level = _99.INFO,
                path = "/tmp/99.debug",
                print_on_error = true,
            },
            
            -- Auto-detected provider (OpenCode > Claude > Copilot)
            -- Or explicitly set: provider = _99.Providers.OpenCodeProvider,
            -- model = "anthropic/claude-opus-4-6",
            
            -- Auto-add AGENT.md files from project directories
            md_files = {
                "AGENT.md",
                "AGENTS.md",
            },
            
            -- Display errors in virtual text
            display_errors = true,
            
            -- Supported languages for treesitter operations
            languages = {
                "lua", "go", "java", "elixir", "cpp", "ruby",
                "rust", "python", "zig", "typescript",
            },
        })

        -- Keymaps
        vim.keymap.set("n", "<leader>9f", function()
            _99.fill_in_function()
        end, { desc = "99: Fill in function" })

        vim.keymap.set("n", "<leader>9F", function()
            _99.fill_in_function_prompt()
        end, { desc = "99: Fill in function (with prompt)" })

        vim.keymap.set("v", "<leader>9v", function()
            _99.visual()
        end, { desc = "99: Process visual selection" })

        vim.keymap.set("v", "<leader>9V", function()
            _99.visual_prompt()
        end, { desc = "99: Process selection (with prompt)" })

        vim.keymap.set("n", "<leader>9s", function()
            _99.stop_all_requests()
        end, { desc = "99: Stop all requests" })

        vim.keymap.set("n", "<leader>9l", function()
            _99.view_logs()
        end, { desc = "99: View logs" })
    end,
}
```

## Keymaps

| Key | Mode | Action |
|-----|------|--------|
| `<leader>9f` | Normal | Fill in function body |
| `<leader>9F` | Normal | Fill in function with prompt |
| `<leader>9v` | Visual | Process visual selection |
| `<leader>9V` | Visual | Process selection with prompt |
| `<leader>9s` | Normal | Stop all requests |
| `<leader>9l` | Normal | View logs |
| `<leader>9[` | Normal | Previous request logs |
| `<leader>9]` | Normal | Next request logs |
| `<leader>9i` | Normal | Show info |
| `<leader>9q` | Normal | Requests to quickfix |
| `<leader>9c` | Normal | Clear previous requests |

## Health Check

Run a built-in diagnostic for provider/model/treesitter readiness:

```lua
:lua require("99").doctor()
```

## Provider Commands

Add these commands to switch providers on the fly:

```lua
-- Switch to OpenCode (Anthropic)
vim.api.nvim_create_user_command("NNOpenCode", function()
    local state = _99.__get_state()
    state.provider_override = _99.Providers.OpenCodeProvider
    state.model = "anthropic/claude-opus-4-6"
    print("99: Switched to OpenCode")
end, {})

-- Switch to Claude Code CLI
vim.api.nvim_create_user_command("NNClaude", function()
    local state = _99.__get_state()
    state.provider_override = _99.Providers.ClaudeCodeProvider
    state.model = "claude-opus-4-6"
    print("99: Switched to Claude Code")
end, {})

-- Switch to Copilot CLI
vim.api.nvim_create_user_command("NNCopilot", function()
    local state = _99.__get_state()
    state.provider_override = _99.Providers.CopilotCLIProvider
    state.model = "claude-opus-4.6"
    print("99: Switched to Copilot CLI")
end, {})

-- Switch to Gemini CLI
vim.api.nvim_create_user_command("NNGemini", function()
    local state = _99.__get_state()
    state.provider_override = _99.Providers.GeminiProvider
    state.model = "gemini-3-pro-preview"
    print("99: Switched to Gemini")
end, {})

-- Switch to Codex CLI
vim.api.nvim_create_user_command("NNCodex", function()
    local state = _99.__get_state()
    state.provider_override = _99.Providers.CodexProvider
    state.model = "gpt-codex-5.3"
    print("99: Switched to Codex")
end, {})

-- Set model with completion
vim.api.nvim_create_user_command("NNModel", function(opts)
    if opts.args ~= "" then
        _99.set_model(opts.args)
        print("99: Model set to " .. opts.args)
    else
        print("99: Current model: " .. _99.__get_state().model)
    end
end, { nargs = "?" })
```

## How It Works

1. **Fill in Function**: Place cursor inside a function, press `<leader>9f`. The AI analyzes the function signature and generates the implementation.

2. **Visual Selection**: Select code, press `<leader>9v`. The AI processes and improves/replaces the selection.

3. **Context**: The plugin automatically includes:
   - `AGENT.md` files from project directories
   - File contents for context
   - Treesitter-parsed function boundaries

4. **Output**: The AI writes code to a temp file, which the plugin reads and inserts into your buffer.

## OpenCode Setup

For OpenCode provider, configure the `neovim` agent in `~/.config/opencode/config.json`:

```json
{
  "agent": {
    "neovim": {
      "description": "Agent for neovim 99 plugin",
      "mode": "all",
      "permission": {
        "external_directory": "allow",
        "read": "allow",
        "edit": "allow",
        "bash": "allow"
      }
    }
  }
}
```

## Supported Languages

Languages with full treesitter query support for function detection:

- Lua, Go, Java, Elixir, C++, Ruby (original)
- Rust, Python, Zig, TypeScript (added in this fork)

## Credits

- Original plugin by [ThePrimeagen](https://github.com/ThePrimeagen/99)
- Multi-provider support and improvements by [sebishogun](https://github.com/sebishogun)
