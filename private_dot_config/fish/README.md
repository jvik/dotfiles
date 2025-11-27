# Fish Shell Configuration

A comprehensive Fish shell configuration ported from ZSH with modern features and enhancements.

## Features

### ✨ Enabled Features

- **Syntax Highlighting**: Built-in syntax highlighting with custom color scheme
- **Autosuggestions**: Fish's intelligent command autosuggestions (built-in)
- **Vi Mode**: Vi keybindings enabled by default
- **Smart History**: Contextual command history with 10,000 entries
- **Fast Startup**: Optimized loading and lazy initialization
- **Tab Completions**: Rich tab completions for common tools

### 🎨 Syntax Highlighting

Fish comes with syntax highlighting built-in. This configuration includes:
- Custom color scheme optimized for visibility
- Command validation (red for invalid commands)
- Quoted string highlighting
- Path autocompletion highlighting

### 📦 Integrations

- **Zoxide**: Fast directory jumping (z command)
- **Homebrew**: Properly initialized for Linux/macOS
- **NVM**: Node Version Manager support
- **FZF**: Fuzzy finding integration
- **Eza**: Modern ls replacement with icons
- **Kubectl**: Kubernetes command completions
- **Git**: Enhanced git integrations

## File Structure

```
~/.config/fish/
├── config.fish           # Main configuration file
├── env.fish             # Environment variables and PATH
├── abbr.fish            # Command abbreviations (expand on space)
├── aliases.fish         # Traditional aliases
├── linux.fish           # Linux-specific settings
├── mac.fish             # macOS-specific settings
├── local.fish.example   # Example local configuration
└── functions/           # Custom functions
    ├── mkcd.fish
    ├── tempe.fish
    ├── pasta.fish
    ├── copy.fish
    ├── fvim.fish
    ├── ghfuzzyclone.fish
    ├── t.fish
    └── git-fworktree.fish
```

## Abbreviations vs Aliases

Fish uses **abbreviations** which expand when you press space (like ZSH aliases), and traditional **aliases** for runtime replacements.

### Key Abbreviations

- `..`, `2..`, `3..`, etc. - Navigate up directories
- `k` - kubectl
- `ka` - kubectl apply -f
- `kg` - kubectl get
- `l` - eza with icons and git status
- `lt` - eza tree view
- `:q`, `q` - exit shell

### Custom Functions

- `mkcd <dir>` - Create directory and cd into it
- `tempe [subdir]` - Create secure temp directory and cd
- `fvim` - Fuzzy find and open file in nvim
- `t` - Sesh session manager with fzf
- `git-fworktree` - Fuzzy select git worktree
- `ghfuzzyclone` - Fuzzy clone GitHub repo
- `pasta` - Paste from clipboard
- `copy [file]` - Copy to clipboard

## Installation

### Prerequisites

Install these tools for full functionality:

```bash
# Core tools
brew install fish eza zoxide fzf

# Optional tools
brew install gh sesh
```

### Enable Fish Shell

```bash
# Add fish to valid shells
echo /usr/bin/fish | sudo tee -a /etc/shells

# Set as default shell
chsh -s /usr/bin/fish
```

### Install Fisher (Plugin Manager) - Optional

```bash
curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher
```

### Recommended Plugins

```bash
# Fzf integration
fisher install PatrickF1/fzf.fish

# Git abbreviations
fisher install jhillyerd/plugin-git

# Kubectl completions
fisher install evanlucas/fish-kubectl-completions
```

## Customization

### Local Configuration

Create `~/.config/fish/local.fish` for machine-specific settings:

```fish
# Example local.fish
set -gx CUSTOM_PATH /my/custom/path
fish_add_path -p /my/custom/path
```

### Theme Customization

Fish supports themes through the `fish_config` web interface:

```bash
fish_config
```

Or install a theme like Tide:

```bash
fisher install IlanCosman/tide@v5
```

## Migration from ZSH

All your ZSH aliases, functions, and environment variables have been ported. Key differences:

- `source` → Fish auto-sources functions from `functions/` directory
- `export VAR=value` → `set -gx VAR value`
- `alias` → Use `abbr` for expanding aliases, `alias` for runtime
- `function() { }` → `function name; ...; end`

## Tips

1. **Reload Config**: `reload-fish` or `source ~/.config/fish/config.fish`
2. **View Abbreviations**: `abbr` (list all)
3. **View Functions**: `functions` (list all)
4. **Help System**: `help <command>` opens browser with docs
5. **Syntax Check**: `fish -n config.fish`

## Performance

Fish is designed to be fast:
- Syntax highlighting is instant
- Completions are generated on-demand
- Functions are lazy-loaded from files
- Startup time should be < 100ms

## Troubleshooting

### Slow Startup

Check what's loading:
```bash
fish --profile config.fish
```

### Missing Features

Ensure tools are installed:
```bash
type -q eza zoxide fzf; and echo "All installed" || echo "Missing tools"
```

## Resources

- [Fish Documentation](https://fishshell.com/docs/current/)
- [Fish Tutorial](https://fishshell.com/docs/current/tutorial.html)
- [Awesome Fish](https://github.com/jorgebucaran/awsm.fish)
