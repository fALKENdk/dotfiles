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
dotfiles restore ~/backups/dotfiles
```

## Prerequisites

Packages are installed automatically via `brew bundle` from the `Brewfile`. Key dependencies:

- **Required**: `git`, `jq`, `openssl`, `tar`
- **Recommended**: `fd`, `rg` (ripgrep), `shellcheck`, `shfmt`, `tree`
- **Secrets**: macOS `security` (built-in) or `pass` (Linux)

## Commands

Unified entrypoint:

```bash
dotfiles
dotfiles <command> help
```

Standalone commands:

- `dotfiles-backup`
- `dotfiles-secrets`
- `dotfiles-ssh`
- `dotfiles-local`

## Backup and Restore

All encrypted backups use a single passphrase (`DOTFILES_BACKUP_PASSPHRASE`).

One-shot backup:

```bash
dotfiles backup
dotfiles backup ~/backups/dotfiles
DOTFILES_BACKUP_PASSPHRASE='...' dotfiles backup ~/backups/dotfiles
```

One-shot restore:

```bash
dotfiles restore ~/backups/dotfiles
dotfiles restore --local ~/local.enc --ssh ~/ssh.enc
DOTFILES_BACKUP_PASSPHRASE='...' dotfiles restore ~/backups/dotfiles
```

When run interactively, `backup` and `restore` prompt once for the passphrase and reuse it for all three modules.

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
dotfiles-local init
dotfiles-local list
```

Expected local files:

- `local/git/.gitconfig-github`
- `local/git/.gitconfig-azure-devops`
- `local/npm/.npmrc-registries`
- `local/secrets/secrets-map.json`

Encrypted backup/restore:

```bash
dotfiles-local backup ~/local.enc
dotfiles-local restore ~/local.enc

# Non-interactive
DOTFILES_BACKUP_PASSPHRASE='strong-passphrase' dotfiles-local backup ~/local.enc
DOTFILES_LOCAL_RESTORE_OVERWRITE=1 dotfiles-local restore ~/local.enc
```

## Secrets and npm Credentials

npm credentials are never stored in tracked files.

- `dotfiles-secrets env` exports secrets into shell env
- `npm/.npmrc` references those environment variables
- Secret mappings live in `local/secrets/secrets-map.json`

Stores:

- macOS: `security` (Keychain)
- Linux: `pass` (Password Store)
- Override: `DOTFILES_SECRETS_STORE=security|pass`

Common commands:

```bash
dotfiles-secrets list
dotfiles-secrets doctor
dotfiles-secrets set AZURE_NPM_USERNAME "your-username"
dotfiles-secrets set AZURE_NPM_PASSWORD_B64 "base64-token"
dotfiles-secrets set AZURE_NPM_EMAIL "you@example.com"
```

Encrypted backup/restore:

```bash
dotfiles-secrets backup ~/secrets.enc
dotfiles-secrets restore ~/secrets.enc

# Non-interactive
DOTFILES_BACKUP_PASSPHRASE='choose-a-strong-passphrase' dotfiles-secrets backup ~/secrets.enc
dotfiles-secrets restore ~/secrets.enc
```

Linux `pass` one-time setup:

```bash
gpg --full-generate-key
pass init "<your-gpg-key-id-or-email>"
```

### Secrets Map Format

The mapping at `local/secrets/secrets-map.json` defines which environment variables correspond to which store entries:

```json
{
  "entries": [
    {
      "env_var": "AZURE_NPM_USERNAME",
      "label": "azure-npm",
      "owner": "__USER__",
      "note": "Azure DevOps NPM feed username"
    }
  ]
}
```

- `env_var` — exported shell variable name (must be a valid identifier)
- `label` — identifier for the secret in the store (Keychain service name or pass path component)
- `owner` — who the secret belongs to; use `"__USER__"` or `""` to resolve to the current OS user at runtime
- `note` — optional human-readable description

Override the map file path with `DOTFILES_SECRETS_MAP_FILE`.

## SSH Key Backup

```bash
dotfiles-ssh list
dotfiles-ssh backup ~/ssh.enc
dotfiles-ssh restore ~/ssh.enc

# Non-interactive / overwrite restore
DOTFILES_BACKUP_PASSPHRASE='choose-a-strong-passphrase' dotfiles-ssh backup ~/ssh.enc
DOTFILES_SSH_RESTORE_OVERWRITE=1 dotfiles-ssh restore ~/ssh.enc
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
- On macOS, `security add-generic-password -w` passes the secret value as a CLI argument, which is briefly visible in the process list. This is a known limitation of the macOS `security` command.
