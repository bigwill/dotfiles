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

---

## Claude Agent Server

A complete setup for running persistent Claude AI agents on remote servers, with mobile access via mosh.

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Your Mac (WezTerm)                                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │ Coordinator │ │  Agent 1    │ │  Agent 2    │  ← Tabs       │
│  │    Tab      │ │    Tab      │ │    Tab      │               │
│  └──────┬──────┘ └──────┬──────┘ └──────┬──────┘               │
│         │               │               │                       │
│         └───────────────┼───────────────┘                       │
│                         │ SSH                                   │
└─────────────────────────┼───────────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────────┐
│  Remote Server (apollo)                                         │
│                                                                 │
│  tmux sessions:                                                 │
│  ┌─────────────────────────────────────────────┐               │
│  │ claude-myrepo-coordinator                    │               │
│  │ ┌─────────────────────────────────────────┐ │               │
│  │ │ watch (status)           │ 25%          │ │               │
│  │ ├─────────────────────────────────────────┤ │               │
│  │ │ shell (merge/review)     │ 75%          │ │               │
│  │ └─────────────────────────────────────────┘ │               │
│  └─────────────────────────────────────────────┘               │
│  ┌─────────────────────┐ ┌─────────────────────┐               │
│  │ claude-myrepo-agent1│ │ claude-myrepo-agent2│               │
│  │ (claude CLI running)│ │ (claude CLI running)│               │
│  └─────────────────────┘ └─────────────────────┘               │
│                                                                 │
│  Git worktrees (isolated working directories):                  │
│  ~/agent-workspace/myrepo/                                      │
│  ├── main/     ← coordinator (base branch)                     │
│  ├── agent1/   ← agent 1 worktree (feature branch)             │
│  └── agent2/   ← agent 2 worktree (feature branch)             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
                          ▲
                          │ mosh (survives network changes)
┌─────────────────────────┼───────────────────────────────────────┐
│  iPhone (Blink Shell)   │                                       │
│  - Check agent status                                           │
│  - Give agents new tasks                                        │
│  - Merge completed work                                         │
└─────────────────────────────────────────────────────────────────┘
```

### Quick Start - Server Setup

```bash
# One-liner to set up a new server
curl -fsSL https://raw.githubusercontent.com/bigwill/dotfiles/main/bootstrap_claude_server.sh | bash

# Start new shell
exec zsh

# Initialize a workspace
cw init myproject git@github.com:user/myproject.git main

# Start the coordinator
cw new myproject main
```

### Quick Start - Mac (WezTerm)

The WezTerm keybindings are set up automatically when you run `bootstrap_mac.sh`.

| Keybinding | Action |
|------------|--------|
| `CMD+SHIFT+C` | Create new Claude workspace (prompts for repo/branch) |
| `CMD+SHIFT+N` | Add new agent tab (prompts for task name) |
| `CMD+SHIFT+W` | Wrap up agent (merge branch, cleanup) |

### Quick Start - iPhone

1. Install **Blink Shell** and **Tailscale** from App Store
2. Set up SSH key with Face ID (Secure Enclave) in Blink
3. Add public key to server's `~/.ssh/authorized_keys`
4. Connect: `mosh yourserver`
5. Use CLI commands: `cw status`, `cw agent taskname`, etc.

### CLI Commands (`cw`)

Run these on the server (or via `cw` wrapper from Mac):

| Command | Description |
|---------|-------------|
| `cw status` | Show all sessions and worktrees |
| `cw new <repo> <branch>` | Create coordinator session |
| `cw agent [name]` | Create/attach to agent (prompts if no name) |
| `cw wrapup [name]` | Merge agent branch and cleanup |
| `cw coord` | Attach to coordinator |
| `cw kill <name\|all>` | Kill session(s) |
| `cw init <repo> <url> [branch]` | Initialize workspace from git |

### Workflow Example

```bash
# 1. On Mac: Create workspace (CMD+SHIFT+C)
#    Or from terminal:
ssh apollo
cw new abax-kryptos rust-ckks-system

# 2. Add agents (CMD+SHIFT+N or from terminal)
cw agent ckks-encoder     # Creates branch: rust-ckks-system-ckks-encoder
cw agent poly-tests       # Creates branch: rust-ckks-system-poly-tests

# 3. In each agent tab, run claude CLI and assign tasks
claude
# "Implement the CKKS encoder from section 2 of PLAN.md"

# 4. Close laptop - agents keep running in tmux!

# 5. Check from iPhone
mosh apollo
cw status
cw agent ckks-encoder   # Reattach to see progress

# 6. When agent is done, merge from coordinator
cw coord
# In bottom pane:
git diff main..rust-ckks-system-ckks-encoder
git merge rust-ckks-system-ckks-encoder

# 7. Cleanup completed agent
cw wrapup ckks-encoder
```

### Files

| File | Location | Purpose |
|------|----------|---------|
| `dot-wezterm.lua` | Mac `~/.wezterm.lua` | WezTerm keybindings |
| `dot-zshrc` | Mac `~/.zshrc` | Mac-side `cw` wrapper |
| `dot-zshrc-claude` | Server `~/.zshrc` | Server-side `cw` CLI |
| `bootstrap_claude_server.sh` | Run on server | Full server setup |

### tmux Shortcuts

Inside a tmux session:

| Shortcut | Action |
|----------|--------|
| `Ctrl+B d` | Detach (session keeps running) |
| `Ctrl+B o` | Switch between panes |
| `Ctrl+B z` | Zoom current pane (toggle) |
| `Ctrl+B [` | Scroll mode (q to exit) |
| `Ctrl+B ↑/↓` | Move to pane above/below |

### Requirements

**Server:**
- Linux (Debian/Ubuntu, RHEL, Arch)
- SSH access
- Git, tmux, mosh (installed by bootstrap script)

**Mac:**
- WezTerm terminal
- SSH key configured for server

**iPhone (optional):**
- Blink Shell app
- Tailscale (for easy remote access)

---

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
