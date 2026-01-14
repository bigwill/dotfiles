#!/usr/bin/env bash
# Git configuration setup script
# Prompts for user name and email, then configures git

set -euo pipefail

echo "[git-setup] Configuring Git..."

# Check if git is installed
if ! command -v git &> /dev/null; then
  echo "[git-setup] Error: Git is not installed"
  echo "[git-setup] Install it with: brew install git"
  exit 1
fi

# Check if .gitconfig exists (should be symlinked from dotfiles)
if [ ! -f "$HOME/.gitconfig" ]; then
  echo "[git-setup] Warning: ~/.gitconfig not found"
  echo "[git-setup] Make sure you've run bootstrap_mac.sh first"
  read -p "[git-setup] Continue anyway? (y/n) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi
fi

# Get current git config (if any)
CURRENT_NAME=$(git config --global user.name 2>/dev/null || echo "")
CURRENT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")

# Prompt for name
if [ -n "$CURRENT_NAME" ]; then
  echo "[git-setup] Current name: $CURRENT_NAME"
  read -p "[git-setup] Enter your name (or press Enter to keep current): " GIT_NAME
  GIT_NAME=${GIT_NAME:-$CURRENT_NAME}
else
  read -p "[git-setup] Enter your name: " GIT_NAME
fi

# Prompt for email
if [ -n "$CURRENT_EMAIL" ]; then
  echo "[git-setup] Current email: $CURRENT_EMAIL"
  read -p "[git-setup] Enter your email (or press Enter to keep current): " GIT_EMAIL
  GIT_EMAIL=${GIT_EMAIL:-$CURRENT_EMAIL}
else
  read -p "[git-setup] Enter your email: " GIT_EMAIL
fi

# Validate inputs
if [ -z "$GIT_NAME" ] || [ -z "$GIT_EMAIL" ]; then
  echo "[git-setup] Error: Name and email are required"
  exit 1
fi

# Set git config
echo "[git-setup] Setting git user.name to: $GIT_NAME"
git config --global user.name "$GIT_NAME"

echo "[git-setup] Setting git user.email to: $GIT_EMAIL"
git config --global user.email "$GIT_EMAIL"

# Verify
echo
echo "[git-setup] Git configuration:"
echo "  Name:  $(git config --global user.name)"
echo "  Email: $(git config --global user.email)"

# Check for GitHub CLI
if command -v gh &> /dev/null; then
  echo
  read -p "[git-setup] Set up GitHub CLI authentication? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[git-setup] Running: gh auth login"
    gh auth login
  fi
else
  echo
  echo "[git-setup] GitHub CLI (gh) not found. Install with: brew install gh"
  echo "[git-setup] Then run: gh auth login"
fi

echo
echo "[git-setup] ✓ Git configuration complete!"
