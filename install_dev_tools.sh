#!/usr/bin/env bash
# Development tools installation script
# Installs common development tools: pixi, conda, Node.js, Rust, Go, etc.

set -euo pipefail

echo "[dev-tools] Development Tools Installation"
echo

# Check for Homebrew
if ! command -v brew &> /dev/null; then
  echo "[dev-tools] Error: Homebrew is not installed"
  echo "[dev-tools] Install it first, then run this script again"
  exit 1
fi

# Function to install a tool if not already installed
install_if_missing() {
  local tool=$1
  local install_cmd=$2
  local check_cmd=${3:-"command -v $tool"}
  
  if eval "$check_cmd" &> /dev/null; then
    echo "[dev-tools] ✓ $tool is already installed"
    return 0
  fi
  
  echo "[dev-tools] Installing $tool..."
  eval "$install_cmd"
  if eval "$check_cmd" &> /dev/null; then
    echo "[dev-tools] ✓ $tool installed successfully"
  else
    echo "[dev-tools] ✗ Failed to install $tool"
    return 1
  fi
}

# pixi
echo "[dev-tools] Checking pixi..."
if command -v pixi &> /dev/null; then
  echo "[dev-tools] ✓ pixi is already installed"
else
  read -p "[dev-tools] Install pixi? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl -fsSL https://pixi.sh/install.sh | bash
    # Add to PATH for current session
    export PATH="$HOME/.pixi/bin:$PATH"
    echo "[dev-tools] ✓ pixi installed. Add to PATH: export PATH=\"\$HOME/.pixi/bin:\$PATH\""
  fi
fi

# Conda (Miniconda)
echo
echo "[dev-tools] Checking conda..."
if command -v conda &> /dev/null || [ -d "$HOME/miniconda3" ] || [ -d "$HOME/anaconda3" ]; then
  echo "[dev-tools] ✓ conda is already installed"
else
  read -p "[dev-tools] Install Miniconda? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[dev-tools] Downloading Miniconda installer..."
    if [[ $(uname -m) == "arm64" ]]; then
      ARCH="arm64"
    else
      ARCH="x86_64"
    fi
    curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-MacOSX-${ARCH}.sh -o /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p "$HOME/miniconda3"
    rm /tmp/miniconda.sh
    echo "[dev-tools] ✓ Miniconda installed. Initialize with: $HOME/miniconda3/bin/conda init zsh"
  fi
fi

# Node.js (via nvm or Homebrew)
echo
echo "[dev-tools] Checking Node.js..."
if command -v node &> /dev/null; then
  echo "[dev-tools] ✓ Node.js is already installed ($(node --version))"
else
  read -p "[dev-tools] Install Node.js? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "[dev-tools] Choose installation method:"
    echo "  1) nvm (Node Version Manager) - recommended"
    echo "  2) Homebrew (system-wide)"
    read -p "[dev-tools] Enter choice (1 or 2): " choice
    case $choice in
      1)
        echo "[dev-tools] Installing nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        echo "[dev-tools] ✓ nvm and Node.js LTS installed"
        ;;
      2)
        install_if_missing "node" "brew install node"
        ;;
      *)
        echo "[dev-tools] Invalid choice, skipping Node.js"
        ;;
    esac
  fi
fi

# Rust
echo
echo "[dev-tools] Checking Rust..."
if command -v rustc &> /dev/null; then
  echo "[dev-tools] ✓ Rust is already installed ($(rustc --version))"
else
  read -p "[dev-tools] Install Rust? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    echo "[dev-tools] ✓ Rust installed"
  fi
fi

# Go
echo
echo "[dev-tools] Checking Go..."
if command -v go &> /dev/null; then
  echo "[dev-tools] ✓ Go is already installed ($(go version))"
else
  read -p "[dev-tools] Install Go? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_if_missing "go" "brew install go"
  fi
fi

# Python (via Homebrew, if not using conda)
echo
echo "[dev-tools] Checking Python..."
if command -v python3 &> /dev/null; then
  echo "[dev-tools] ✓ Python3 is already installed ($(python3 --version))"
else
  read -p "[dev-tools] Install Python3? (y/n) " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    install_if_missing "python3" "brew install python@3.12"
  fi
fi

# Cloud CLIs
echo
echo "[dev-tools] Cloud CLI Tools:"
read -p "[dev-tools] Install gcloud CLI? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  if command -v gcloud &> /dev/null; then
    echo "[dev-tools] ✓ gcloud is already installed"
  else
    echo "[dev-tools] Installing gcloud CLI..."
    brew install --cask google-cloud-sdk
    echo "[dev-tools] ✓ gcloud installed. Run 'gcloud init' to configure"
  fi
fi

read -p "[dev-tools] Install AWS CLI? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  install_if_missing "aws" "brew install awscli"
fi

echo
echo "[dev-tools] ✓ Development tools installation complete!"
echo
echo "[dev-tools] Next steps:"
echo "  - Restart your terminal or run: exec zsh"
echo "  - Configure conda if installed: conda init zsh"
echo "  - Configure gcloud if installed: gcloud init"
