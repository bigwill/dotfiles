#!/usr/bin/env bash
# Export Homebrew packages to Brewfile for sharing between machines

set -euo pipefail

DOTFILES_DIR="$HOME/git/dotfiles"
BREWFILE="$DOTFILES_DIR/Brewfile"

if [ ! -d "$DOTFILES_DIR" ]; then
  echo "Error: $DOTFILES_DIR not found"
  exit 1
fi

echo "Exporting Homebrew packages to $BREWFILE..."

# Export both formulas and casks
brew bundle dump --file="$BREWFILE" --force

echo "✓ Exported to $BREWFILE"
echo
echo "To install on another machine:"
echo "  brew bundle install --file=$BREWFILE"
