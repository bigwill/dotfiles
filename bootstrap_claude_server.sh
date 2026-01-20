#!/usr/bin/env bash
# Bootstrap script for Claude Agent servers
# Sets up: tmux, mosh, zsh, Claude workspace CLI (cw)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/bigwill/dotfiles/main/bootstrap_claude_server.sh | bash
#   # or
#   ./bootstrap_claude_server.sh

set -euo pipefail

echo "[bootstrap] Starting Claude Agent server setup for $(whoami) on $(hostname)"

# ----------------------------
# 1. Install base packages
# ----------------------------
install_packages() {
  if command -v apt-get &>/dev/null; then
    echo "[bootstrap] Installing packages via apt..."
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
      zsh git curl ca-certificates tmux htop vim mosh \
      build-essential
    sudo rm -rf /var/lib/apt/lists/*
  elif command -v yum &>/dev/null; then
    echo "[bootstrap] Installing packages via yum..."
    sudo yum install -y zsh git curl tmux htop vim mosh
  elif command -v pacman &>/dev/null; then
    echo "[bootstrap] Installing packages via pacman..."
    sudo pacman -Sy --noconfirm zsh git curl tmux htop vim mosh
  else
    echo "[bootstrap] Warning: No supported package manager found."
    echo "[bootstrap] Please install manually: zsh git tmux mosh"
  fi
}

install_packages

# ----------------------------
# 2. Install Oh My Zsh
# ----------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "[bootstrap] Installing Oh My Zsh..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || true
else
  echo "[bootstrap] Oh My Zsh already present."
fi

# ----------------------------
# 3. Install powerlevel10k theme
# ----------------------------
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
P10K_DIR="$ZSH_CUSTOM/themes/powerlevel10k"

if [ ! -d "$P10K_DIR" ]; then
  echo "[bootstrap] Installing powerlevel10k..."
  git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
  echo "[bootstrap] powerlevel10k already installed."
fi

# ----------------------------
# 4. Clone dotfiles
# ----------------------------
mkdir -p "$HOME/git"

if [ ! -d "$HOME/git/dotfiles" ]; then
  echo "[bootstrap] Cloning bigwill/dotfiles..."
  git clone https://github.com/bigwill/dotfiles.git "$HOME/git/dotfiles"
else
  echo "[bootstrap] dotfiles already exists, pulling latest..."
  git -C "$HOME/git/dotfiles" pull --ff-only || true
fi

# ----------------------------
# 5. Set up .zshrc - symlink to dot-zshrc-claude
# ----------------------------
DOT_ZSHRC="$HOME/git/dotfiles/dot-zshrc-claude"

if [ -f "$DOT_ZSHRC" ]; then
  if [ -f "$HOME/.zshrc" ] || [ -L "$HOME/.zshrc" ]; then
    # Check if already correctly symlinked
    if [ "$(readlink "$HOME/.zshrc" 2>/dev/null)" != "$DOT_ZSHRC" ]; then
      echo "[bootstrap] Backing up existing .zshrc..."
      mv "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
    fi
  fi
  
  if [ "$(readlink "$HOME/.zshrc" 2>/dev/null)" != "$DOT_ZSHRC" ]; then
    echo "[bootstrap] Symlinking $DOT_ZSHRC -> ~/.zshrc"
    ln -sf "$DOT_ZSHRC" "$HOME/.zshrc"
  else
    echo "[bootstrap] .zshrc already correctly symlinked."
  fi
else
  echo "[bootstrap] Warning: $DOT_ZSHRC not found. Creating basic .zshrc..."
  cat > "$HOME/.zshrc" <<'EOF'
# Basic zshrc - dot-zshrc-claude not found
export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
plugins=(git)
[ -d "$ZSH" ] && source "$ZSH/oh-my-zsh.sh"
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF
fi

echo "[bootstrap] .zshrc configured"

# ----------------------------
# 6. Symlink p10k config
# ----------------------------
DOT_P10K="$HOME/git/dotfiles/dot-p10k.zsh"

if [ -f "$DOT_P10K" ]; then
  if [ -f "$HOME/.p10k.zsh" ] && [ "$(readlink "$HOME/.p10k.zsh" 2>/dev/null)" != "$DOT_P10K" ]; then
    mv "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup.$(date +%s)"
  fi
  ln -sf "$DOT_P10K" "$HOME/.p10k.zsh"
  echo "[bootstrap] Linked p10k config"
fi

# ----------------------------
# 7. Create agent workspace directory
# ----------------------------
mkdir -p "$HOME/agent-workspace"
echo "[bootstrap] Created ~/agent-workspace"

# ----------------------------
# 8. Set up mosh server (if firewall needs config)
# ----------------------------
echo "[bootstrap] Mosh installed. Default ports: 60000-61000 UDP"
echo "[bootstrap] If using a firewall, ensure these ports are open."

# Check if ufw is active and add rules
if command -v ufw &>/dev/null && sudo ufw status | grep -q "active"; then
  echo "[bootstrap] Configuring ufw for mosh..."
  sudo ufw allow 60000:61000/udp
fi

# ----------------------------
# 9. Change default shell to zsh
# ----------------------------
if command -v zsh &>/dev/null; then
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "[bootstrap] Changing default shell to zsh..."
    if command -v chsh &>/dev/null; then
      chsh -s "$(command -v zsh)" "$(whoami)" 2>/dev/null || true
    fi
  fi
fi

# ----------------------------
# 10. Install Claude CLI (optional - requires npm)
# ----------------------------
if command -v npm &>/dev/null; then
  echo "[bootstrap] npm found. To install Claude CLI later, run:"
  echo "  npm install -g @anthropic-ai/claude-code"
else
  echo "[bootstrap] npm not found. Install Node.js to use Claude CLI."
fi

# ----------------------------
# Done
# ----------------------------
echo ""
echo "=========================================="
echo "[bootstrap] Claude Agent Server Ready!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Start a new shell:  exec zsh"
echo "  2. Initialize a workspace:"
echo "     cw init <repo-name> <git-url> [branch]"
echo "  3. Start working:"
echo "     cw new <repo-name> <branch>"
echo "     cw agent <agent-name>"
echo ""
echo "Mobile access via mosh:"
echo "  mosh $(whoami)@$(hostname)"
echo ""
echo "Workspace directory: ~/agent-workspace"
echo ""
