# iMac Setup Checklist

Things to sync/configure when setting up your iMac to match your MacBook.

## ✅ Already Handled (via dotfiles)

- [x] Cursor settings & keybindings
- [x] WezTerm configuration
- [x] Powerlevel10k theme
- [x] SizeUp preferences
- [x] 1Password (you mentioned)
- [x] Dropbox (you mentioned)

## 🔑 SSH & Git Authentication

### SSH Keys
- [x] **`~/.ssh/config` already in dotfiles** (contains 1Password agent setup + host configs)
- [ ] On iMac: Enable 1Password SSH agent (Settings → Developer → Enable SSH Agent)
- [ ] Add SSH keys to 1Password (if not already there)
  - Option 1: Generate new SSH keys in 1Password app
  - Option 2: Add existing keys to 1Password (run `sync_ssh.sh` for help)
- [ ] Add public keys to GitHub/GitLab/etc. (from 1Password)
- [ ] Test SSH connection: `ssh -T git@github.com` (if using SSH for GitHub)

### GitHub CLI (gh)
- [ ] Run `gh auth login` on iMac
- [ ] **Consider adding `~/.config/gh/config.yml` to dotfiles** (if it has useful config)
- [ ] Verify `gh auth git-credential` works (already in your .gitconfig)

## 📝 Shell Configuration

### .zshrc
Your `.zshrc` has:
- Custom aliases (`cdla`, `cdha`, `cl`, `ak`)
- PATH additions (pixi, .local/bin, lmstudio)
- App Store Connect API keys (⚠️ sensitive - consider 1Password)
- Conda lazy loading

**Options:**
1. **Add to dotfiles** - Create `dot-zshrc` with shared parts, keep machine-specific in local file
2. **Template approach** - Create `dot-zshrc.template` with placeholders
3. **Source pattern** - Have `.zshrc` source `~/git/dotfiles/dot-zshrc` for shared config

### .gitconfig
- [ ] **Add to dotfiles** - Create `dot-gitconfig` (remove/placeholder user.email/name)
- [ ] Set user.name and user.email on iMac after symlinking

## 🍺 Homebrew

### Package Management
- [ ] Install Homebrew on iMac
- [ ] Export package list: `brew bundle dump --file=~/git/dotfiles/Brewfile`
- [ ] On iMac: `brew bundle install --file=~/git/dotfiles/Brewfile`

**Current packages to sync:**
- Many development tools (abseil, boost, cairo, etc.)
- Casks: iTerm2, macfuse, rar, serial

## 🐳 Docker

- [ ] **Consider adding `~/.docker/config.json` to dotfiles** (if it has useful config)
- [ ] Verify Docker Desktop settings match

## 🔧 Development Tools

### Language Runtimes
- [ ] **pixi** - Install and configure (already in PATH)
- [ ] **LM Studio** - Install if needed (in PATH)
- [ ] **Conda** - Install if needed (lazy-loaded in .zshrc)
- [ ] Node.js/npm/pnpm/yarn (if used)
- [ ] Python/pip (if used)
- [ ] Rust/cargo (if used)
- [ ] Go (if used)

### Cloud CLIs
- [ ] **gcloud** - Already has config in `~/.config/gcloud`
- [ ] AWS CLI (if used)
- [ ] Other cloud providers

## ⌨️ System Preferences

### Keyboard & Input
- [ ] Keyboard shortcuts (System Settings → Keyboard)
- [ ] Text replacements/autocorrect
- [ ] Input sources/languages

### Trackpad/Mouse
- [ ] Trackpad gestures
- [ ] Mouse settings (if using external)

### Display
- [ ] Resolution/scaling
- [ ] Color profile
- [ ] Night Shift/True Tone

### Dock
- [ ] Dock position (left/bottom/right)
- [ ] Auto-hide setting
- [ ] Icon size
- [ ] **Consider exporting**: `defaults read com.apple.dock > ~/git/dotfiles/dot-dock.plist`

### Finder
- [ ] View options (show hidden files, etc.)
- [ ] Sidebar items
- [ ] Default view (list/icon/column)

## 📦 Application Settings

### Cursor
- [x] Settings & keybindings (already in dotfiles)
- [ ] Extensions - Install same extensions on iMac
  - Check: `~/.cursor/extensions/` or Cursor's extension marketplace
- [ ] Workspace settings (if any)

### Terminal Fonts
- [ ] Install **JetBrainsMono Nerd Font** (used in Cursor settings)
- [ ] Verify WezTerm uses correct font

### Other Apps
- [ ] Browser bookmarks/extensions (if using sync, ensure it's enabled)
- [ ] Any other dev tools with configs

## 🔐 Secrets & Credentials

### Already in 1Password
- [x] Passwords
- [ ] **API Keys** - Move App Store Connect keys from .zshrc to 1Password
  - `APP_STORE_CONNECT_API_KEY_ID`
  - `APP_STORE_CONNECT_ISSUER_ID`
- [x] SSH keys (using 1Password SSH agent)

### Environment Variables
- [ ] Create `~/.zshenv` or `~/.zshrc.local` for machine-specific secrets
- [ ] Source from 1Password CLI or environment

## 📁 File Organization

### Git Repos
- [ ] Clone frequently used repos to `~/git/`
- [ ] Set up any git worktrees
- [ ] Configure git LFS if needed (already in .gitconfig)

### Project Directories
- [ ] Recreate directory structure
- [ ] Symlink from Dropbox if needed

## 🚀 Quick Setup Script Ideas

Consider creating:
1. `install_homebrew.sh` - Install Homebrew + essential packages
2. `install_dev_tools.sh` - Install language runtimes, CLIs
3. `sync_ssh.sh` - Set up SSH keys with 1Password (migrate existing or generate new)
4. `setup_git.sh` - Configure git user info

## 📋 Recommended Additions to Dotfiles

1. **`dot-ssh-config`** - SSH configuration (1Password agent, hosts)
2. **`dot-zshrc`** - Shared shell config (aliases, PATH, functions)
3. **`dot-gitconfig`** - Git config (without user info)
4. **`Brewfile`** - Homebrew packages list
5. **`dot-dock.plist`** - Dock preferences (optional)

## 🎯 Priority Order

1. **Critical** (blocks development):
   - 1Password SSH agent setup (SSH config already in dotfiles)
   - Git config & GitHub auth
   - Homebrew & essential packages
   - Shell config (.zshrc)

2. **Important** (quality of life):
   - Cursor extensions
   - System preferences
   - Development tools (pixi, conda, etc.)

3. **Nice to have**:
   - Dock/Finder preferences
   - Browser bookmarks
   - Other app settings
