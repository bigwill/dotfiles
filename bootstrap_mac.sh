#!/usr/bin/env bash
# Mac bootstrap script for dotfiles
# Run this on a new Mac to set up symlinks for shared configs
#
# Usage:
#   ./bootstrap_mac.sh           # Normal mode
#   ./bootstrap_mac.sh --dry-run # Preview changes without making them

set -euo pipefail

# Parse arguments
DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]] || [[ "${1:-}" == "-n" ]]; then
  DRY_RUN=true
  echo "[bootstrap] DRY RUN MODE - No changes will be made"
  echo
fi

echo "[bootstrap] Starting Mac bootstrap for $(whoami) on $(hostname)"

DOTFILES_DIR="$HOME/git/dotfiles"

# Ensure dotfiles directory exists
if [ ! -d "$DOTFILES_DIR" ]; then
  echo "[bootstrap] Error: $DOTFILES_DIR not found"
  echo "[bootstrap] Please clone your dotfiles repo first:"
  echo "  git clone <your-repo> $DOTFILES_DIR"
  exit 1
fi

# Function to safely symlink a file
symlink_file() {
  local source="$1"
  local target="$2"
  local description="$3"

  if [ ! -f "$source" ]; then
    echo "[bootstrap] Warning: $source not found, skipping $description"
    return
  fi

  # If target exists and is not a symlink, back it up
  if [ -e "$target" ] && [ ! -L "$target" ]; then
    if [ "$DRY_RUN" = true ]; then
      echo "[bootstrap] [DRY RUN] Would backup existing $target"
    else
      echo "[bootstrap] Backing up existing $target..."
      mv "$target" "${target}.backup.$(date +%s)"
    fi
  fi

  # If target is already the correct symlink, skip
  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    echo "[bootstrap] $description is already correctly symlinked"
    return
  fi

  # Create parent directory if needed
  if [ "$DRY_RUN" = true ]; then
    echo "[bootstrap] [DRY RUN] Would create directory: $(dirname "$target")"
    echo "[bootstrap] [DRY RUN] Would symlink $source -> $target"
  else
    mkdir -p "$(dirname "$target")"
    echo "[bootstrap] Symlinking $source -> $target"
    ln -sf "$source" "$target"
  fi
}

# Verification function
verify_symlink() {
  local source="$1"
  local target="$2"
  local description="$3"

  if [ ! -f "$source" ]; then
    return 1  # Source doesn't exist, skip verification
  fi

  if [ "$DRY_RUN" = true ]; then
    return 0  # Skip verification in dry-run mode
  fi

  if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
    if [ -f "$target" ]; then
      echo "[verify] ✓ $description is correctly symlinked"
      return 0
    else
      echo "[verify] ✗ $description symlink is broken"
      return 1
    fi
  elif [ -e "$target" ]; then
    echo "[verify] ✗ $description exists but is not a symlink"
    return 1
  else
    echo "[verify] ✗ $description symlink is missing"
    return 1
  fi
}

# Check and install Homebrew if needed
check_homebrew() {
  if command -v brew &> /dev/null; then
    echo "[bootstrap] ✓ Homebrew is installed"
    return 0
  fi

  echo "[bootstrap] Homebrew not found"
  if [ "$DRY_RUN" = true ]; then
    echo "[bootstrap] [DRY RUN] Would install Homebrew"
    return 0
  fi

  echo "[bootstrap] Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # Add Homebrew to PATH
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    echo "[bootstrap] ✓ Homebrew installed (Apple Silicon)"
  elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    echo "[bootstrap] ✓ Homebrew installed (Intel)"
  else
    echo "[bootstrap] ⚠ Homebrew installation may have failed"
    return 1
  fi
}

# Install essential apps and tools
install_essential_apps() {
  if [ "$DRY_RUN" = true ]; then
    echo "[bootstrap] [DRY RUN] Would check/install essential apps"
    return 0
  fi

  if ! command -v brew &> /dev/null; then
    echo "[bootstrap] Homebrew not installed, skipping app installation"
    return 1
  fi

  echo "[bootstrap] Checking essential apps..."

  # WezTerm
  if brew list --cask wezterm &> /dev/null; then
    echo "[bootstrap] ✓ WezTerm is already installed"
  else
    echo "[bootstrap] Installing WezTerm..."
    if brew install --cask wezterm; then
      echo "[bootstrap] ✓ WezTerm installed"
    else
      echo "[bootstrap] ⚠ Failed to install WezTerm"
    fi
  fi

  # SizeUp
  if brew list --cask sizeup &> /dev/null; then
    echo "[bootstrap] ✓ SizeUp is already installed"
  else
    echo "[bootstrap] Installing SizeUp..."
    if brew install --cask sizeup; then
      echo "[bootstrap] ✓ SizeUp installed"
    else
      echo "[bootstrap] ⚠ Failed to install SizeUp"
    fi
  fi

  # Powerlevel10k (via Homebrew or oh-my-zsh)
  if [ -f "/opt/homebrew/opt/powerlevel10k/powerlevel10k.zsh-theme" ] || \
     [ -f "/usr/local/opt/powerlevel10k/powerlevel10k.zsh-theme" ] || \
     [ -f "$HOME/.oh-my-zsh/custom/themes/powerlevel10k/powerlevel10k.zsh-theme" ]; then
    echo "[bootstrap] ✓ Powerlevel10k is already installed"
  else
    echo "[bootstrap] Installing Powerlevel10k..."
    
    # Try Homebrew first (preferred method)
    if brew install powerlevel10k &> /dev/null; then
      echo "[bootstrap] ✓ Powerlevel10k installed via Homebrew"
    else
      # Fall back to oh-my-zsh installation
      # Install oh-my-zsh if needed
      if [ ! -d "$HOME/.oh-my-zsh" ]; then
        echo "[bootstrap] Installing oh-my-zsh..."
        if sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended &> /dev/null; then
          echo "[bootstrap] ✓ oh-my-zsh installed"
        else
          echo "[bootstrap] ⚠ Failed to install oh-my-zsh"
        fi
      fi
      
      if [ -d "$HOME/.oh-my-zsh" ]; then
        echo "[bootstrap] Installing Powerlevel10k via oh-my-zsh..."
        if git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
          "$HOME/.oh-my-zsh/custom/themes/powerlevel10k" 2>/dev/null; then
          echo "[bootstrap] ✓ Powerlevel10k installed via oh-my-zsh"
        else
          echo "[bootstrap] ⚠ Failed to install Powerlevel10k"
        fi
      fi
    fi
  fi
}

# Install packages from Brewfile if it exists
install_brewfile() {
  local brewfile="$DOTFILES_DIR/Brewfile"
  
  if [ ! -f "$brewfile" ]; then
    echo "[bootstrap] Brewfile not found, skipping package installation"
    return 0
  fi

  if [ "$DRY_RUN" = true ]; then
    echo "[bootstrap] [DRY RUN] Would install packages from Brewfile"
    return 0
  fi

  if ! command -v brew &> /dev/null; then
    echo "[bootstrap] Homebrew not installed, skipping Brewfile installation"
    return 1
  fi

  echo "[bootstrap] Installing packages from Brewfile..."
  if brew bundle install --file="$brewfile"; then
    echo "[bootstrap] ✓ Successfully installed packages from Brewfile"
  else
    echo "[bootstrap] ⚠ Some packages from Brewfile failed to install (this is often normal)"
  fi
}

# Main symlink setup
echo "[bootstrap] Setting up symlinks..."

# 1. Powerlevel10k config
symlink_file "$DOTFILES_DIR/dot-p10k.zsh" "$HOME/.p10k.zsh" ".p10k.zsh"

# 2. WezTerm config
symlink_file "$DOTFILES_DIR/dot-wezterm.lua" "$HOME/.wezterm.lua" ".wezterm.lua"

# 2.5. SSH config
if [ -f "$DOTFILES_DIR/dot-ssh-config" ]; then
  SSH_DIR="$HOME/.ssh"
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
  fi
  symlink_file "$DOTFILES_DIR/dot-ssh-config" "$SSH_DIR/config" "SSH config"
  if [ "$DRY_RUN" = false ]; then
    chmod 600 "$SSH_DIR/config" 2>/dev/null || true
  fi
else
  echo "[bootstrap] dot-ssh-config not found in dotfiles, skipping"
fi

# 3. Cursor settings
CURSOR_USER_DIR="$HOME/Library/Application Support/Cursor/User"
if [ -d "$CURSOR_USER_DIR" ] || [ "$DRY_RUN" = true ]; then
  symlink_file "$DOTFILES_DIR/dot-cursor-settings.json" "$CURSOR_USER_DIR/settings.json" "Cursor settings.json"
  symlink_file "$DOTFILES_DIR/dot-cursor-keybindings.json" "$CURSOR_USER_DIR/keybindings.json" "Cursor keybindings.json"
else
  echo "[bootstrap] Cursor User directory not found, skipping Cursor configs"
fi

# 4. SizeUp preferences
if [ -f "$DOTFILES_DIR/dot-sizeup.plist" ]; then
  SIZEUP_PLIST="$HOME/Library/Preferences/com.irradiatedsoftware.SizeUp.plist"
  if [ "$DRY_RUN" = false ] && [ -f "$SIZEUP_PLIST" ] && [ ! -L "$SIZEUP_PLIST" ]; then
    echo "[bootstrap] Backing up existing SizeUp plist..."
    cp "$SIZEUP_PLIST" "${SIZEUP_PLIST}.backup.$(date +%s)"
  fi
  symlink_file "$DOTFILES_DIR/dot-sizeup.plist" "$SIZEUP_PLIST" "SizeUp preferences"
else
  echo "[bootstrap] dot-sizeup.plist not found in dotfiles, skipping"
fi

# 5. Git config
if [ -f "$DOTFILES_DIR/dot-gitconfig" ]; then
  symlink_file "$DOTFILES_DIR/dot-gitconfig" "$HOME/.gitconfig" ".gitconfig"
else
  echo "[bootstrap] dot-gitconfig not found in dotfiles, skipping"
fi

# 6. Zsh config
if [ -f "$DOTFILES_DIR/dot-zshrc" ]; then
  symlink_file "$DOTFILES_DIR/dot-zshrc" "$HOME/.zshrc" ".zshrc"
else
  echo "[bootstrap] dot-zshrc not found in dotfiles, skipping"
fi

# Verification step
if [ "$DRY_RUN" = false ]; then
  echo
  echo "[bootstrap] Verifying symlinks..."
  VERIFY_FAILED=0
  
  verify_symlink "$DOTFILES_DIR/dot-p10k.zsh" "$HOME/.p10k.zsh" ".p10k.zsh" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-wezterm.lua" "$HOME/.wezterm.lua" ".wezterm.lua" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-ssh-config" "$HOME/.ssh/config" "SSH config" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-cursor-settings.json" "$CURSOR_USER_DIR/settings.json" "Cursor settings.json" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-cursor-keybindings.json" "$CURSOR_USER_DIR/keybindings.json" "Cursor keybindings.json" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-sizeup.plist" "$HOME/Library/Preferences/com.irradiatedsoftware.SizeUp.plist" "SizeUp preferences" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-gitconfig" "$HOME/.gitconfig" ".gitconfig" || VERIFY_FAILED=1
  verify_symlink "$DOTFILES_DIR/dot-zshrc" "$HOME/.zshrc" ".zshrc" || VERIFY_FAILED=1
  
  if [ $VERIFY_FAILED -eq 0 ]; then
    echo "[bootstrap] ✓ All symlinks verified successfully"
  else
    echo "[bootstrap] ⚠ Some symlinks failed verification"
  fi
fi

# Homebrew setup
echo
if check_homebrew; then
  install_essential_apps
  install_brewfile
fi

echo
if [ "$DRY_RUN" = true ]; then
  echo "[bootstrap] Dry run complete. Run without --dry-run to apply changes."
else
  echo "[bootstrap] Done! Next steps:"
  echo "  1. Restart your terminal or run: exec zsh"
  echo "  2. Configure git user info: git config --global user.name 'Your Name'"
  echo "  3. Configure git user email: git config --global user.email 'your.email@example.com'"
  echo "  4. Run: gh auth login (for GitHub CLI)"
  echo "  5. Review SETUP_CHECKLIST.md for additional setup steps"
fi
