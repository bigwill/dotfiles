# Dotfiles

Shared configuration files for Mac development setup.

## What's Included

### Configuration Files
- **Powerlevel10k** (`dot-p10k.zsh`) - Zsh theme configuration
- **WezTerm** (`dot-wezterm.lua`) - Terminal configuration
- **Cursor** (`dot-cursor-settings.json`, `dot-cursor-keybindings.json`) - Editor settings
- **SizeUp** (`dot-sizeup.plist`) - Window management preferences
- **SSH Config** (`dot-ssh-config`) - SSH configuration with 1Password agent setup
- **Zsh Config** (`dot-zshrc`) - Shared shell configuration (aliases, PATH, conda lazy loading)
- **Git Config** (`dot-gitconfig`) - Git configuration template (user info set separately)

### Scripts
- **`bootstrap_mac.sh`** - Main bootstrap script for setting up a new Mac
- **`setup_git.sh`** - Interactive Git configuration (name, email, GitHub CLI)
- **`install_dev_tools.sh`** - Install development tools (pixi, conda, Node.js, Rust, Go, etc.)
- **`sync_ssh.sh`** - SSH key setup and synchronization helper
- **`export_brewfile.sh`** - Export Homebrew packages to Brewfile

### Documentation
- **`SETUP_CHECKLIST.md`** - Comprehensive checklist for setting up a new Mac

## Quick Start

### On a New Mac

1. Clone this repository:
   ```bash
   git clone <your-repo-url> ~/git/dotfiles
   ```

2. Run the bootstrap script:
   ```bash
   ~/git/dotfiles/bootstrap_mac.sh
   ```

   This will:
   - Create symlinks for all config files
   - Back up any existing configs
   - Verify all symlinks are correct
   - Check for Homebrew and offer to install it
   - Install packages from `Brewfile` if it exists

3. Configure Git:
   ```bash
   ~/git/dotfiles/setup_git.sh
   ```

4. Set up SSH keys:
   ```bash
   ~/git/dotfiles/sync_ssh.sh
   ```

5. Install development tools (optional):
   ```bash
   ~/git/dotfiles/install_dev_tools.sh
   ```

### Dry Run Mode

Preview changes without applying them:
```bash
~/git/dotfiles/bootstrap_mac.sh --dry-run
```

## Bootstrap Script Features

The `bootstrap_mac.sh` script includes:

- **Safe symlinking** - Backs up existing files before overwriting
- **Dry-run mode** - Preview changes with `--dry-run` or `-n`
- **Verification** - Checks all symlinks after creation
- **Homebrew integration** - Checks for Homebrew and offers to install it
- **Brewfile support** - Automatically installs packages from `Brewfile` if present
- **Idempotent** - Safe to run multiple times

## Helper Scripts

### `setup_git.sh`
Interactive script to configure Git:
- Prompts for user name and email
- Sets git config globally
- Optionally sets up GitHub CLI authentication

### `install_dev_tools.sh`
Interactive installer for common development tools:
- **pixi** - Package manager
- **Conda** - Python environment manager
- **Node.js** - Via nvm or Homebrew
- **Rust** - Via rustup
- **Go** - Via Homebrew
- **Python** - Via Homebrew
- **Cloud CLIs** - gcloud, AWS CLI

### `sync_ssh.sh`
SSH key setup helper:
- Checks for existing SSH keys
- Generates new SSH keys
- Guides copying keys from another machine
- Helps set up 1Password SSH agent
- Tests GitHub SSH connection

## Homebrew Package Management

### Export packages from your MacBook:
```bash
~/git/dotfiles/export_brewfile.sh
```

This creates a `Brewfile` in the dotfiles directory.

### Install packages on a new Mac:
The bootstrap script will automatically install packages from `Brewfile` if it exists. Or manually:
```bash
brew bundle install --file=~/git/dotfiles/Brewfile
```

## Manual Setup

If you prefer to set up manually:

```bash
ln -sf ~/git/dotfiles/dot-p10k.zsh ~/.p10k.zsh
ln -sf ~/git/dotfiles/dot-wezterm.lua ~/.wezterm.lua
ln -sf ~/git/dotfiles/dot-zshrc ~/.zshrc
ln -sf ~/git/dotfiles/dot-gitconfig ~/.gitconfig
ln -sf ~/git/dotfiles/dot-cursor-settings.json ~/Library/Application\ Support/Cursor/User/settings.json
ln -sf ~/git/dotfiles/dot-cursor-keybindings.json ~/Library/Application\ Support/Cursor/User/keybindings.json
ln -sf ~/git/dotfiles/dot-sizeup.plist ~/Library/Preferences/com.irradiatedsoftware.SizeUp.plist
ln -sf ~/git/dotfiles/dot-ssh-config ~/.ssh/config
chmod 600 ~/.ssh/config
```

## Configuration Notes

### Machine-Specific Settings

Some settings are machine-specific and should be configured separately:

- **Git user info** - Use `setup_git.sh` or manually:
  ```bash
  git config --global user.name "Your Name"
  git config --global user.email "your.email@example.com"
  ```

- **Secrets/API keys** - Store in `~/.zshenv.local` or `~/.zshrc.local`:
  ```bash
  # These files are sourced by dot-zshrc if they exist
  # Keep them out of git (add to .gitignore)
  ```

- **1Password SSH Agent** - Enable in 1Password:
  - Settings → Developer → Enable "Use the SSH agent"
  - The SSH config is already set up to use it

## Next Steps

After running the bootstrap script, see `SETUP_CHECKLIST.md` for a comprehensive list of additional setup steps including:
- System preferences
- Application settings
- Development environment setup
- Cloud CLI configuration
