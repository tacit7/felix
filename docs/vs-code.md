# 1. Install the Extension

Method 1: VS Code Extensions Panel

- Open VS Code
- Go to Extensions (Ctrl/Cmd + Shift + X)
- Search for "ElixirLS: Elixir support and debugger"
- Click Install

Method 2: Command Line
code --install-extension jakebecker.elixir-ls

2. Configure VS Code Settings

Add these to your VS Code settings (Cmd/Ctrl + Shift + P → "Preferences: Open Settings (JSON)"):

```
  {
    // Elixir-specific settings
    "elixirLS.dialyzerEnabled": true,
    "elixirLS.fetchDeps": false,
    "elixirLS.suggestSpecs": true,

    // Auto-format on save
    "[elixir]": {
      "editor.formatOnSave": true,
      "editor.insertSpaces": true,
      "editor.tabSize": 2
    },

    // File associations
    "files.associations": {
      "*.ex": "elixir",
      "*.exs": "elixir",
      "*.heex": "phoenix-heex",
      "mix.lock": "elixir"
    },

    // Additional helpful settings
    "editor.rulers": [98], // Phoenix default line length
    "editor.wordWrap": "wordWrapColumn",
    "editor.wordWrapColumn": 98
  }

  3. Project-Specific Configuration

  Create .vscode/settings.json in your Phoenix project root:

  {
    "elixirLS.projectDir": ".",
    "elixirLS.mixEnv": "dev",
    "elixirLS.mixTarget": "host",

    // Enable formatting
    "[elixir]": {
      "editor.formatOnSave": true,
      "editor.defaultFormatter": "JakeBecker.elixir-ls"
    },

    // Phoenix-specific file watching
    "files.watcherExclude": {
      "**/_build/**": true,
      "**/deps/**": true,
      "**/node_modules/**": true
    }
  }
```

4. Additional Recommended Extensions

Install these complementary extensions:

# Phoenix LiveView support

code --install-extension phoenixframework.phoenix

# Better syntax highlighting

code --install-extension mjmcloug.vscode-elixir

# Git integration

code --install-extension eamodio.gitlens

5. ElixirLS Features You'll Get

- Auto-completion: Context-aware code completion
- Go to definition: Navigate to function definitions
- Format on save: Automatic mix format on file save
- Dialyzer integration: Static analysis for type checking
- Inline documentation: Hover to see function docs
- Debugging support: Set breakpoints and debug Elixir code

6. Verify Installation

After installation, you should see:

- Elixir file syntax highlighting
- Auto-completion when typing
- Format on save working
- ElixirLS status in the bottom status bar

7. Troubleshooting

If ElixirLS doesn't work:

# In your Phoenix project directory

mix deps.get
mix compile

# Restart ElixirLS in VS Code

Cmd/Ctrl + Shift + P → "ElixirLS: Restart"

Now when you save any .ex or .exs file, it will automatically format using mix format!

Ready to continue with the cache backend implementations
