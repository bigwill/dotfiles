#!/usr/bin/env bash
#set -euo pipefail

echo "[bootstrap] Starting bootstrap for $(whoami) on $(hostname)"

# ----------------------------
# 1. Install base packages (Debian/Ubuntu-style, e.g. RunPod)
# ----------------------------
if command -v apt-get &>/dev/null; then
  echo "[bootstrap] Installing packages via apt..."
  sudo apt-get update
  sudo apt-get install -y --no-install-recommends \
    zsh git curl ca-certificates tmux htop vim pipx \
    && sudo rm -rf /var/lib/apt/lists/*

  echo "[bootstrap] Installing gpustat..."
  pipx install gpustat || echo "[bootstrap] Warning: gpustat install failed"
else
  echo "[bootstrap] No apt-get found, skipping package install."
fi

# ----------------------------
# 2. Install Oh My Zsh (if missing)
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
# 4. Write .zshrc configured for p10k
# ----------------------------
if [ -f "$HOME/.zshrc" ]; then
  echo "[bootstrap] Backing up existing .zshrc to .zshrc.backup.$(date +%s)"
  cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%s)"
fi

cat > "$HOME/.zshrc" <<'EOF'
export PATH="$HOME/.local/bin:$PATH"
export PATH="/usr/local/cuda/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"

# Use powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Basic plugins
plugins=(git)

# Optional: disable instant prompt on remote FS to avoid weirdness
export POWERLEVEL9K_INSTANT_PROMPT=off

# Load Oh My Zsh
if [ -d "$ZSH" ]; then
  source "$ZSH/oh-my-zsh.sh"
fi

# Load powerlevel10k config if present
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

echo "[bootstrap] Wrote ~/.zshrc"

# ----------------------------
# 5. Clone dotfiles and symlink ~/.p10k.zsh
# ----------------------------
mkdir -p "$HOME/git"

if [ ! -d "$HOME/git/dotfiles" ]; then
  echo "[bootstrap] Cloning humbleaudio/dotfiles into ~/git/dotfiles..."
  git clone git@github.com:humbleaudio/dotfiles.git "$HOME/git/dotfiles"
else
  echo "[bootstrap] Repo ~/git/dotfiles already exists, pulling latest..."
  git -C "$HOME/git/dotfiles" pull --ff-only || true
fi

DOT_P10K="$HOME/git/dotfiles/dot-p10k.zsh"

if [ -f "$DOT_P10K" ]; then
  if [ -f "$HOME/.p10k.zsh" ] || [ -L "$HOME/.p10k.zsh" ]; then
    # Check if it's already the correct symlink
    if [ "$(readlink "$HOME/.p10k.zsh")" != "$DOT_P10K" ]; then
      echo "[bootstrap] Backing up existing .p10k.zsh..."
      mv "$HOME/.p10k.zsh" "$HOME/.p10k.zsh.backup.$(date +%s)"
    fi
  fi

  # Only link if not already linked correctly (or if we just moved the old one)
  if [ "$(readlink "$HOME/.p10k.zsh")" != "$DOT_P10K" ]; then
    echo "[bootstrap] Symlinking $DOT_P10K -> ~/.p10k.zsh"
    ln -sf "$DOT_P10K" "$HOME/.p10k.zsh"
  else
     echo "[bootstrap] .p10k.zsh is already correctly symlinked."
  fi
else
  echo "[bootstrap] Warning: $DOT_P10K not found. Skipping p10k setup."
fi

# ----------------------------
# 6. Clone your Blackwell repo into ~/git/blackwell
# ----------------------------
# mkdir -p "$HOME/git" # Created in step 5
if [ ! -d "$HOME/git/blackwell" ]; then
  echo "[bootstrap] Cloning humbleaudio/blackwell into ~/git/blackwell..."
  git clone git@github.com:humbleaudio/blackwell.git "$HOME/git/blackwell"
else
  echo "[bootstrap] Repo ~/git/blackwell already exists, pulling latest..."
  git -C "$HOME/git/blackwell" pull --ff-only || true
fi

# ----------------------------
# 7. Try to change default shell to zsh
# ----------------------------
if command -v zsh &>/dev/null; then
  if [ "$SHELL" != "$(command -v zsh)" ]; then
    echo "[bootstrap] Changing default shell to zsh (best effort)..."
    if command -v chsh &>/dev/null; then
      chsh -s "$(command -v zsh)" "$(whoami)" || true
    fi
  fi
else
  echo "[bootstrap] zsh not found, skipping chsh."
fi

echo
echo "[bootstrap] Done. Start a new shell or run: exec zsh"

