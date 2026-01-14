#!/usr/bin/env bash
# Clone common repositories
# Usage: ./clone_repos.sh

set -euo pipefail

GIT_DIR="$HOME/git"
REPOS=(
  "femme"
  "abax-kryptos"
  "ableton-mcp"
  "prince-logo"
  "todo-dashboard"
)

# Ensure git directory exists
mkdir -p "$GIT_DIR"

# GitHub username (can be overridden with GITHUB_USER env var)
GITHUB_USER="${GITHUB_USER:-bigwill}"

echo "[clone] Cloning repositories to $GIT_DIR"
echo

for repo in "${REPOS[@]}"; do
  repo_path="$GIT_DIR/$repo"
  
  if [ -d "$repo_path" ]; then
    echo "[clone] ✓ $repo already exists at $repo_path"
    continue
  fi
  
  # Special case: femme is owned by humbleaudio
  if [ "$repo" = "femme" ]; then
    repo_user="humbleaudio"
  else
    repo_user="$GITHUB_USER"
  fi
  
  repo_url="https://github.com/$repo_user/$repo.git"
  echo "[clone] Cloning $repo from $repo_user..."
  
  if git clone "$repo_url" "$repo_path" 2>&1; then
    echo "[clone] ✓ Successfully cloned $repo"
  else
    echo "[clone] ✗ Failed to clone $repo"
  fi
  echo
done

echo "[clone] Done!"
