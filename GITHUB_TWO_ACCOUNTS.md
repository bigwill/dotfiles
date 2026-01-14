# Using SSH with Two GitHub Accounts

If you want to use SSH for GitHub with two accounts, here's how to set it up.

## Quick Answer

**If you use HTTPS for GitHub** (which you mentioned you do), you don't need SSH keys for GitHub at all! Your `gh auth git-credential` setup handles authentication.

However, if you want to switch to SSH or need it for other services, here's how to set up two accounts.

## Setup Steps

### 1. Generate Two SSH Keys

Run the sync script and choose option 1, then select "2" for two keys:

```bash
~/git/dotfiles/sync_ssh.sh
# Choose option 1, then enter "2" for number of keys
```

Or manually:
```bash
# First account (e.g., personal)
ssh-keygen -t ed25519 -C "personal@example.com" -f ~/.ssh/id_ed25519_personal

# Second account (e.g., work)
ssh-keygen -t ed25519 -C "work@example.com" -f ~/.ssh/id_ed25519_work
```

### 2. Add Public Keys to GitHub

Add each public key to the corresponding GitHub account:

- First account: https://github.com/settings/keys
- Second account: https://github.com/settings/keys

```bash
# View public keys
cat ~/.ssh/id_ed25519_personal.pub
cat ~/.ssh/id_ed25519_work.pub
```

### 3. Configure SSH Config

Add entries to `~/.ssh/config` (or update `dot-ssh-config` in your dotfiles):

```ssh-config
# First GitHub account
Host github.com-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_personal

# Second GitHub account
Host github.com-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_work
```

### 4. Use Different URLs for Repos

When cloning or setting remote URLs, use the host aliases:

```bash
# For first account repos
git clone git@github.com-personal:username/repo.git

# For second account repos
git clone git@github.com-work:username/repo.git

# Or update existing remotes
git remote set-url origin git@github.com-personal:username/repo.git
```

### 5. Configure Git Per-Repo

Set the correct user info per repository:

```bash
# For personal repos
cd ~/git/personal-repo
git config user.name "Personal Name"
git config user.email "personal@example.com"

# For work repos
cd ~/git/work-repo
git config user.name "Work Name"
git config user.email "work@example.com"
```

## Alternative: Keep Using HTTPS

Since you're already using HTTPS with `gh auth git-credential`, you can:

1. **Keep using HTTPS** - No SSH keys needed for GitHub
2. **Use different GitHub accounts** - `gh auth login` can handle multiple accounts
3. **Set per-repo git config** - Different user.name/email per repo

This is often simpler than SSH for multiple accounts!

## Using 1Password for SSH Keys

If you migrate your SSH keys to 1Password:

1. Add both keys to 1Password as "SSH Key" items
2. The 1Password SSH agent will automatically use the correct key
3. You still need the SSH config host aliases above
4. The `IdentityFile` entries in SSH config can reference 1Password-managed keys

## Testing

Test your setup:

```bash
# Test first account
ssh -T git@github.com-personal

# Test second account
ssh -T git@github.com-work
```

You should see messages like:
```
Hi username! You've successfully authenticated...
```
