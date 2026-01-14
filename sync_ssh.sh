#!/usr/bin/env bash
# SSH key setup and synchronization script
# Helps set up SSH keys with 1Password agent support

set -euo pipefail

echo "[ssh-setup] SSH Key Setup"
echo
echo "Note: If you use HTTPS for GitHub (with gh auth), you don't need SSH keys for GitHub."
echo "      However, SSH keys are useful for:"
echo "      - Other Git services (GitLab, Bitbucket, etc.)"
echo "      - Remote server access (already configured in your SSH config)"
echo "      - Switching to SSH for GitHub later"
echo

# Check if SSH directory exists
SSH_DIR="$HOME/.ssh"
if [ ! -d "$SSH_DIR" ]; then
  echo "[ssh-setup] Creating ~/.ssh directory..."
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
fi

# Check if SSH config is symlinked
if [ -L "$SSH_DIR/config" ]; then
  echo "[ssh-setup] ✓ SSH config is symlinked from dotfiles"
  CONFIG_SOURCE=$(readlink "$SSH_DIR/config")
  if [[ "$CONFIG_SOURCE" == *"dotfiles"* ]]; then
    echo "[ssh-setup]   Source: $CONFIG_SOURCE"
  fi
elif [ -f "$SSH_DIR/config" ]; then
  echo "[ssh-setup] ⚠ SSH config exists but is not symlinked"
  echo "[ssh-setup]   Run bootstrap_mac.sh to symlink it"
else
  echo "[ssh-setup] ✗ SSH config not found"
  echo "[ssh-setup]   Run bootstrap_mac.sh to set it up"
fi

# Check for 1Password SSH agent
OP_SSH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
if [ -S "$OP_SSH_SOCK" ]; then
  echo "[ssh-setup] ✓ 1Password SSH agent socket found"
else
  echo "[ssh-setup] ⚠ 1Password SSH agent socket not found"
  echo "[ssh-setup]   Make sure 1Password is installed and SSH agent is enabled"
  echo "[ssh-setup]   1Password → Settings → Developer → Enable SSH Agent"
fi

# Check for existing SSH keys
echo
echo "[ssh-setup] Checking for SSH keys..."
EXISTING_KEYS=()
for key_file in "$SSH_DIR"/id_*; do
  if [ -f "$key_file" ] && [[ "$key_file" != *.pub ]]; then
    EXISTING_KEYS+=("$key_file")
  fi
done

if [ ${#EXISTING_KEYS[@]} -eq 0 ]; then
  echo "[ssh-setup] No SSH keys found"
else
  echo "[ssh-setup] Found SSH keys:"
  for key in "${EXISTING_KEYS[@]}"; do
    echo "  - $key"
    if [ -f "${key}.pub" ]; then
      FINGERPRINT=$(ssh-keygen -lf "${key}.pub" 2>/dev/null | awk '{print $2}' || echo "unknown")
      echo "    Fingerprint: $FINGERPRINT"
    fi
  done
fi

# Options for setting up SSH keys
echo
echo "[ssh-setup] SSH Key Setup Options:"
echo "  1) Generate a new SSH key"
echo "  2) Copy SSH keys from another machine"
echo "  3) Migrate existing SSH keys to 1Password"
echo "  4) Use 1Password SSH keys (if already in 1Password)"
echo "  5) Skip (keys already set up)"
read -p "[ssh-setup] Choose an option (1-5): " choice

case $choice in
  1)
    echo "[ssh-setup] Generate New SSH Key"
    echo
    read -p "[ssh-setup] How many keys do you need? (1 or 2 for two GitHub accounts): " num_keys
    num_keys=${num_keys:-1}
    
    if [ "$num_keys" = "2" ]; then
      echo "[ssh-setup] Setting up SSH keys for two GitHub accounts"
      echo "[ssh-setup] You'll need to configure SSH host aliases (see help at end)"
      echo
      
      # First key
      read -p "[ssh-setup] Enter name for first key (e.g., github-personal, default: id_ed25519_personal): " key1_name
      key1_name=${key1_name:-id_ed25519_personal}
      read -p "[ssh-setup] Enter email/comment for first key: " key1_email
      key1_path="$SSH_DIR/$key1_name"
      
      if [ -f "$key1_path" ]; then
        echo "[ssh-setup] Key $key1_path already exists"
        read -p "[ssh-setup] Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "[ssh-setup] Skipping first key"
        else
          echo "[ssh-setup] Generating first SSH key..."
          ssh-keygen -t ed25519 -C "$key1_email" -f "$key1_path" -N ""
          chmod 600 "$key1_path"
          chmod 644 "${key1_path}.pub"
          echo "[ssh-setup] ✓ First key generated: $key1_path"
          echo "[ssh-setup] Public key:"
          cat "${key1_path}.pub"
          echo
        fi
      else
        echo "[ssh-setup] Generating first SSH key..."
        ssh-keygen -t ed25519 -C "$key1_email" -f "$key1_path" -N ""
        chmod 600 "$key1_path"
        chmod 644 "${key1_path}.pub"
        echo "[ssh-setup] ✓ First key generated: $key1_path"
        echo "[ssh-setup] Public key:"
        cat "${key1_path}.pub"
        echo
      fi
      
      # Second key
      read -p "[ssh-setup] Enter name for second key (e.g., github-work, default: id_ed25519_work): " key2_name
      key2_name=${key2_name:-id_ed25519_work}
      read -p "[ssh-setup] Enter email/comment for second key: " key2_email
      key2_path="$SSH_DIR/$key2_name"
      
      if [ -f "$key2_path" ]; then
        echo "[ssh-setup] Key $key2_path already exists"
        read -p "[ssh-setup] Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "[ssh-setup] Skipping second key"
        else
          echo "[ssh-setup] Generating second SSH key..."
          ssh-keygen -t ed25519 -C "$key2_email" -f "$key2_path" -N ""
          chmod 600 "$key2_path"
          chmod 644 "${key2_path}.pub"
          echo "[ssh-setup] ✓ Second key generated: $key2_path"
          echo "[ssh-setup] Public key:"
          cat "${key2_path}.pub"
          echo
        fi
      else
        echo "[ssh-setup] Generating second SSH key..."
        ssh-keygen -t ed25519 -C "$key2_email" -f "$key2_path" -N ""
        chmod 600 "$key2_path"
        chmod 644 "${key2_path}.pub"
        echo "[ssh-setup] ✓ Second key generated: $key2_path"
        echo "[ssh-setup] Public key:"
        cat "${key2_path}.pub"
        echo
      fi
      
      echo
      echo "[ssh-setup] Next steps for two GitHub accounts:"
      echo "  1. Add first public key to your first GitHub account"
      echo "  2. Add second public key to your second GitHub account"
      echo "  3. Add SSH config entries (see example below)"
      echo
      echo "[ssh-setup] Example SSH config entries (~/.ssh/config):"
      echo "  # First GitHub account"
      echo "  Host github.com-personal"
      echo "    HostName github.com"
      echo "    User git"
      echo "    IdentityFile ~/.ssh/$key1_name"
      echo ""
      echo "  # Second GitHub account"
      echo "  Host github.com-work"
      echo "    HostName github.com"
      echo "    User git"
      echo "    IdentityFile ~/.ssh/$key2_name"
      echo ""
      echo "[ssh-setup] Then use different URLs for repos:"
      echo "  git@github.com-personal:username/repo.git  (for first account)"
      echo "  git@github.com-work:username/repo.git     (for second account)"
    else
      # Single key
      read -p "[ssh-setup] Enter key name (default: id_ed25519): " key_name
      key_name=${key_name:-id_ed25519}
      key_path="$SSH_DIR/$key_name"
      
      if [ -f "$key_path" ]; then
        echo "[ssh-setup] Key $key_path already exists"
        read -p "[ssh-setup] Overwrite? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
          echo "[ssh-setup] Skipping key generation"
          exit 0
        fi
      fi
      
      read -p "[ssh-setup] Enter email for key comment: " key_email
      echo "[ssh-setup] Generating SSH key..."
      ssh-keygen -t ed25519 -C "$key_email" -f "$key_path" -N ""
      chmod 600 "$key_path"
      chmod 644 "${key_path}.pub"
      
      echo "[ssh-setup] ✓ SSH key generated: $key_path"
      echo
      echo "[ssh-setup] Public key:"
      cat "${key_path}.pub"
      echo
      echo "[ssh-setup] Add this public key to:"
      echo "  - GitHub: https://github.com/settings/keys (if using SSH)"
      echo "  - GitLab: https://gitlab.com/-/profile/keys"
      echo "  - Other services as needed"
    fi
    ;;
    
  2)
    echo "[ssh-setup] To copy SSH keys from another machine:"
    echo
    echo "  On the source machine, run:"
    echo "    scp ~/.ssh/id_* user@imac:~/.ssh/"
    echo
    echo "  Or use rsync:"
    echo "    rsync -avz ~/.ssh/ user@imac:~/.ssh/"
    echo
    echo "  Then set correct permissions:"
    echo "    chmod 700 ~/.ssh"
    echo "    chmod 600 ~/.ssh/id_*"
    echo "    chmod 644 ~/.ssh/*.pub"
    ;;
    
  3)
    echo "[ssh-setup] Migrating SSH Keys to 1Password"
    echo
    echo "This will help you move your existing SSH keys into 1Password."
    echo "Benefits:"
    echo "  - Keys are encrypted and synced across devices"
    echo "  - No need to manually copy keys to new machines"
    echo "  - Keys are protected by 1Password's security"
    echo "  - Automatic key management via SSH agent"
    echo
    
    if [ ${#EXISTING_KEYS[@]} -eq 0 ]; then
      echo "[ssh-setup] No existing SSH keys found to migrate"
      echo "[ssh-setup] Generate a new key in 1Password instead (option 4)"
      exit 0
    fi
    
    echo "[ssh-setup] Found ${#EXISTING_KEYS[@]} SSH key(s) to migrate:"
    for key in "${EXISTING_KEYS[@]}"; do
      echo "  - $key"
    done
    echo
    
    # Check if 1Password is installed
    if ! command -v op &> /dev/null; then
      echo "[ssh-setup] ⚠ 1Password CLI (op) not found"
      echo "[ssh-setup] Install it: brew install --cask 1password-cli"
      echo
      echo "[ssh-setup] Or manually add keys via 1Password app:"
      echo "  1. Open 1Password app"
      echo "  2. Create a new 'SSH Key' item (or 'Secure Note')"
      echo "  3. Copy the private key content from:"
      for key in "${EXISTING_KEYS[@]}"; do
        echo "     - $key"
      done
      echo "  4. Paste into the 'Private Key' field"
      echo "  5. Add the public key (.pub file) to GitHub/GitLab/etc."
      echo "  6. Enable SSH agent in 1Password: Settings → Developer → Enable SSH Agent"
      exit 0
    fi
    
    # Check if logged into 1Password CLI
    if ! op account list &> /dev/null; then
      echo "[ssh-setup] Not logged into 1Password CLI"
      echo "[ssh-setup] Run: op signin"
      exit 1
    fi
    
    echo "[ssh-setup] Steps to migrate each key:"
    echo
    for key in "${EXISTING_KEYS[@]}"; do
      key_name=$(basename "$key")
      key_basename="${key_name%.*}"
      pub_key="${key}.pub"
      
      echo "[ssh-setup] Processing: $key_name"
      
      if [ ! -f "$pub_key" ]; then
        echo "[ssh-setup] ⚠ Public key not found: $pub_key"
        echo "[ssh-setup] Skipping this key"
        continue
      fi
      
      # Get public key fingerprint
      FINGERPRINT=$(ssh-keygen -lf "$pub_key" 2>/dev/null | awk '{print $2}' || echo "unknown")
      echo "[ssh-setup]   Fingerprint: $FINGERPRINT"
      
      # Show public key
      echo "[ssh-setup]   Public key:"
      cat "$pub_key" | sed 's/^/     /'
      echo
      
      read -p "[ssh-setup] Add '$key_name' to 1Password? (y/n) " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "[ssh-setup] Skipping $key_name"
        continue
      fi
      
      # Create SSH key item in 1Password
      echo "[ssh-setup] Creating SSH key item in 1Password..."
      
      # Read private key
      PRIVATE_KEY=$(cat "$key")
      PUBLIC_KEY=$(cat "$pub_key")
      
      # Create the item (using op item create)
      # Note: This is a simplified version - you may need to adjust based on your 1Password setup
      echo "[ssh-setup] Manual steps for $key_name:"
      echo "  1. In 1Password app, create a new 'SSH Key' item"
      echo "  2. Title: SSH Key - $key_basename"
      echo "  3. Private Key field:"
      echo "     $(head -1 "$key")"
      echo "     ... (full key in: $key)"
      echo "  4. Public Key field:"
      echo "     $(cat "$pub_key")"
      echo "  5. Notes: Fingerprint: $FINGERPRINT"
      echo
      echo "  Or use 1Password CLI (if you have a vault name):"
      echo "    op item create --category 'Secure Note' --title 'SSH Key - $key_basename' \\"
      echo "      --field 'label=Private Key' --field 'value=$(cat "$key")' \\"
      echo "      --field 'label=Public Key' --field 'value=$(cat "$pub_key")'"
      echo
      
      read -p "[ssh-setup] Have you added this key to 1Password? (y/n) " -n 1 -r
      echo
      if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "[ssh-setup] ✓ Key added to 1Password"
        
        # Ask if they want to remove the local key (after verifying 1Password works)
        echo "[ssh-setup] ⚠ Keep local key for now until you verify 1Password works"
        echo "[ssh-setup]   Test with: ssh -T git@github.com"
        echo "[ssh-setup]   Once verified, you can remove: $key"
      fi
      echo
    done
    
    echo "[ssh-setup] Next steps:"
    echo "  1. Enable SSH agent in 1Password: Settings → Developer → Enable SSH Agent"
    echo "  2. Restart terminal or run: exec zsh"
    echo "  3. Test SSH: ssh -T git@github.com"
    echo "  4. Once verified, you can optionally remove local keys (they're in 1Password now)"
    echo "  5. Update SSH config to remove IdentityFile entries (1Password handles this)"
    ;;
    
  4)
    echo "[ssh-setup] 1Password SSH Key Setup:"
    echo
    echo "If you already have SSH keys in 1Password:"
    echo
    echo "  1. In 1Password, go to Settings → Developer"
    echo "  2. Enable 'Use the SSH agent'"
    echo "  3. Make sure your SSH keys are added as 'SSH Key' items in 1Password"
    echo "  4. The SSH config should already be configured to use 1Password agent"
    echo
    echo "  Your SSH config should include:"
    echo "    Host *"
    echo "      IdentityAgent ~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    echo
    echo "  To generate a new SSH key in 1Password:"
    echo "  1. In 1Password app, click '+' → 'SSH Key'"
    echo "  2. Fill in the details and generate"
    echo "  3. Copy the public key and add to GitHub/GitLab/etc."
    ;;
    
  5)
    echo "[ssh-setup] Skipping SSH key setup"
    ;;
    
  *)
    echo "[ssh-setup] Invalid choice"
    exit 1
    ;;
esac

# Test SSH connection to GitHub
echo
read -p "[ssh-setup] Test SSH connection to GitHub? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo "[ssh-setup] Testing SSH connection to GitHub..."
  if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "[ssh-setup] ✓ SSH connection to GitHub successful!"
  else
    echo "[ssh-setup] ⚠ SSH connection test failed or key not added to GitHub"
    echo "[ssh-setup]   Make sure you've added your public key to GitHub"
  fi
fi

echo
echo "[ssh-setup] ✓ SSH setup complete!"
