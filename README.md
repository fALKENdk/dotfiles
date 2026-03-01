# Dotfiles

Minimal cross-platform dotfiles with local/private data kept out of git.

## Quick Start

```bash
git clone git@github.com:fALKENdk/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./scripts/install.sh
```

Use `~/.dotfiles` to keep `$HOME` clean.

## Fresh macOS Bootstrap

For a brand-new Mac:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh)
```

This runs: Xcode CLT install, clone, package install, local config seed, symlinks, and macOS defaults.

Optional:

```bash
# Skip macOS defaults
bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh) --skip-macos

# Disable remote installers (Oh My Zsh / Cursor installer)
DOTFILES_ALLOW_REMOTE_INSTALLERS=0 ~/.dotfiles/scripts/install.sh
```

After bootstrap, restore private backups (if available):

```bash
local-config restore ~/local-config.enc
ssh-keys-backup restore ~/ssh-keys.enc
```

## Commands

Unified entrypoint:

```bash
dotfiles
dotfiles <command> help
```

Standalone commands also work:

- `dotfiles-backup`
- `local-config`
- `keychain-secrets`
- `ssh-keys-backup`

One-shot backup:

```bash
dotfiles backup
dotfiles backup ~/backups/dotfiles
DOTFILES_BACKUP_DIR=~/backups/dotfiles dotfiles backup
```

## Home Directory Policy

Use top-level links only for core shell/git files. Use XDG-style paths for runtime state and helper commands.

- Top-level links: `~/.zshrc`, `~/.zprofile`, `~/.gitconfig*`, `~/.gitignore_global`, `~/.npmrc`, `~/.ssh/config`
- Platform marker: `~/.config/dotfiles/platform`
- Helper commands: `~/.local/bin`
- Homebrew shell init is handled by `zsh/.zprofile` (`eval "$(brew shellenv)"`)

## Platform Model

Platform selection happens at install time:

- `scripts/packages.sh` installs shared packages and platform-specific extras
- `scripts/symlinks.sh` writes `~/.config/dotfiles/platform`
- `zsh/.zshrc` stays platform-neutral and loads:
  - `zsh/.platform-common`
  - `zsh/.platform-<platform>`

On macOS, `./scripts/install.sh` runs `scripts/macos.sh` unless `--skip-macos` is used.

## Local Config (`local/`)

Machine-specific files live in `local/` (gitignored). Templates live in `local.example/` (tracked).

Seed local files:

```bash
local-config init
local-config list
```

Expected local files:

- `local/git/.gitconfig-github`
- `local/git/.gitconfig-azure-devops`
- `local/npm/.npmrc-registries`
- `local/secrets/secrets-map.json`

Encrypted backup/restore:

```bash
local-config backup ~/local-config.enc
local-config restore ~/local-config.enc

# Non-interactive
LOCAL_CONFIG_PASSPHRASE='strong-passphrase' local-config backup ~/local-config.enc
LOCAL_CONFIG_RESTORE_OVERWRITE=1 local-config restore ~/local-config.enc
```

## Secrets and npm Credentials

npm credentials are never stored in tracked files.

- `keychain-secrets env development` exports secrets into shell env
- `npm/.npmrc` references those environment variables
- Secret mappings live in `local/secrets/secrets-map.json`

Backends:

- macOS: `security` (Keychain)
- Linux: `pass` (Password Store)
- Override: `KEYCHAIN_SECRETS_BACKEND=security|pass`

Common commands:

```bash
keychain-secrets list
keychain-secrets doctor
keychain-secrets set AZURE_NPM_USERNAME "your-username"
keychain-secrets set AZURE_NPM_PASSWORD_B64 "base64-token"
keychain-secrets set AZURE_NPM_EMAIL "you@example.com"
```

Encrypted backup/restore:

```bash
keychain-secrets backup all ~/keychain-all.enc
keychain-secrets restore ~/keychain-all.enc

# Non-interactive
export KEYCHAIN_BACKUP_PASSPHRASE='choose-a-strong-passphrase'
keychain-secrets backup development ~/keychain-dev.enc
keychain-secrets restore ~/keychain-dev.enc
```

Linux `pass` one-time setup:

```bash
gpg --full-generate-key
pass init "<your-gpg-key-id-or-email>"
```

## SSH Key Backup

```bash
ssh-keys-backup list
ssh-keys-backup backup ~/ssh-keys.enc
ssh-keys-backup restore ~/ssh-keys.enc

# Non-interactive / overwrite restore
export SSH_KEYS_BACKUP_PASSPHRASE='choose-a-strong-passphrase'
SSH_KEYS_RESTORE_OVERWRITE=1 ssh-keys-backup restore ~/ssh-keys.enc
```

## Package Installation

Packages are defined in `Brewfile` and installed with `brew bundle` from `scripts/packages.sh`.
Linux additionally installs `pass`.

Cursor is installed through the official installer (unless disabled by `DOTFILES_ALLOW_REMOTE_INSTALLERS=0`), and CLI linking is attempted where supported.

## Security Notes

- Private keys stay in `~/.ssh` and are never tracked
- Personal identity and secret mappings live in `local/` (gitignored)
- Secrets are stored in Keychain/`pass`, not in git
- Run `./scripts/audit.sh` before commits

