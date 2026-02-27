# Dotfiles

Minimal, migration-friendly cross-platform dotfiles.

## Quick Start

```bash
git clone git@github.com:fALKENdk/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./scripts/install.sh
```

`~/.dotfiles` is recommended to keep `$HOME` cleaner.

## Unified CLI

After install, every command is available through a single entry point:

```bash
dotfiles                    # show all available commands
dotfiles <command> help     # show subcommand details
```

The standalone commands (`keychain-secrets`, `local-config`, `ssh-keys-backup`) continue to work as before.

### One-shot backup

Back up local config, secrets (`all` collection), and SSH keys in one command:

```bash
dotfiles backup
```

Set a custom backup folder either by argument or environment variable:

```bash
dotfiles backup ~/backups/dotfiles
DOTFILES_BACKUP_DIR=~/backups/dotfiles dotfiles backup
```

This also works as a standalone command after symlinks are installed:

```bash
dotfiles-backup ~/backups/dotfiles
```

## Fresh macOS Bootstrap (new machine)

On a brand-new Mac with nothing installed, run a single command:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh)
```

This handles everything automatically:

1. Installs Xcode Command Line Tools (provides `git`, compilers)
2. Clones this repo to `~/.dotfiles`
3. Runs `install.sh` (Homebrew, packages, Oh My Zsh, local config, symlinks, macOS defaults)

After bootstrap, restore your personal config and SSH keys:

```bash
local-config restore ~/local-config.enc
ssh-keys-backup restore ~/ssh-keys.enc
git -C ~/.dotfiles remote set-url origin git@github.com:fALKENdk/dotfiles.git
~/.dotfiles/scripts/symlinks.sh
```

Skip macOS defaults by passing the flag through:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh) --skip-macos
```

Hardened mode (disable remote installers such as Oh My Zsh and Cursor installer):

```bash
DOTFILES_ALLOW_REMOTE_INSTALLERS=0 ~/.dotfiles/scripts/install.sh
```

In this mode, install those tools manually before or after setup.

## Platform Model

Platform is selected at install time, not in your hot shell path:

- `scripts/packages.sh` installs shared packages from `Brewfile` and platform-specific extras
- `scripts/symlinks.sh` writes the platform marker to `~/.config/dotfiles/platform`
- `.zshrc` stays platform-neutral and sources:
  - `zsh/.platform-common`
  - `zsh/.platform-<platform>` based on the platform marker

On macOS, `./scripts/install.sh` applies `scripts/macos.sh` automatically.
Use `--skip-macos` only if you intentionally want to skip system defaults.

## Home Directory Policy

Keep `$HOME` clean:

- Required top-level links: `~/.zshrc`, `~/.zprofile`, `~/.gitconfig*`, `~/.gitignore_global`, `~/.npmrc`, `~/.ssh/config`
- Platform state lives in `~/.config/dotfiles/platform`
- Helper commands live in `~/.local/bin`

## Local Config

Machine-specific files live in `local/` (gitignored). Templates live in `local.example/` (tracked).

On first install, `local-config init` seeds `local/` from the templates. Edit the files with your actual values:

- `local/git/.gitconfig-github` -- your GitHub name and email
- `local/git/.gitconfig-azure-devops` -- your work name and email
- `local/npm/.npmrc-registries` -- private registry URLs
- `local/secrets/secrets-map.json` -- keychain-secrets mapping entries

### Backup/restore (encrypted)

```bash
local-config backup ~/local-config.enc
local-config restore ~/local-config.enc

# Non-interactive
LOCAL_CONFIG_PASSPHRASE='strong-passphrase' local-config backup ~/local-config.enc
LOCAL_CONFIG_RESTORE_OVERWRITE=1 local-config restore ~/local-config.enc
```

### Other commands

```bash
local-config init      # seed local/ from templates (skips existing files)
local-config list      # show files in local/
```

## What Brew Installs (and why)

- `git` - ensures git is available and consistent after setup.
- `nvm` - Node.js version manager used by your shell config.
- `jq` - JSON processor used by `keychain-secrets` for secrets map parsing.
- `fd` - fast `find` replacement used by `local-config` for file listing.
- `ripgrep` - fast `grep` replacement used by `audit.sh` for secret scanning.
- `tree` - directory listing used by `local-config list`.
- `shellcheck` - shell script linter used by `audit.sh`.
- `shfmt` - shell script formatter used for auto-format on save and `audit.sh`.
- `bitwarden-cli` - Bitwarden CLI (`bw`).
- `dotnet` - .NET SDK/runtime.
- `azure/azd/azd` - Azure Developer CLI.
- `cursor` - installed via official installer (`curl https://cursor.com/install -fsS | bash`), then CLI is linked if needed.

No VS Code extensions are installed by this setup.

### Linux note (Ubuntu, etc.)

- `scripts/packages.sh` installs packages from the shared `Brewfile` and adds `pass` on Linux.
- Cursor is installed via official installer (`curl https://cursor.com/install -fsS | bash`).
- `scripts/symlinks.sh` links Cursor settings to `~/.config/Cursor/User/settings.json` on Linux.

## NPM Secret Handling

This repo does not store npm credentials in files.
`zsh/.zshrc` loads secrets via `keychain-secrets env development`.
`npm/.npmrc` references those exported variables.

`keychain-secrets` uses a backend:

- macOS: `security` (Keychain)
- Linux: `pass` (Password Store)
- Override manually with `KEYCHAIN_SECRETS_BACKEND=security|pass`

Secrets are defined once in `local/secrets/secrets-map.json`:

- `collection` (examples: `development`, `wifi`)
- `env_var` (what shell/npm sees)
- `service` (Keychain service name)
- `account` (`__USER__` means current macOS user)
- `note` (description)

Example entry:

```json
{
  "collection": "development",
  "env_var": "AZURE_NPM_USERNAME",
  "service": "dotfiles.azure.npm.username",
  "account": "__USER__",
  "note": "Azure Artifacts username"
}
```

### Common commands

```bash
# List all mapped secrets
keychain-secrets list

# List one collection
keychain-secrets list development

# Check which secrets are present/missing
keychain-secrets doctor

# Store/update one secret value
keychain-secrets set AZURE_NPM_USERNAME "your-username"
keychain-secrets set AZURE_NPM_PASSWORD_B64 "base64-token"
keychain-secrets set AZURE_NPM_EMAIL "you@example.com"
```

Linux `pass` one-time setup (if needed):

```bash
gpg --full-generate-key
pass init "<your-gpg-key-id-or-email>"
```

### Backup/restore (encrypted)

```bash
# Interactive passphrase prompt
keychain-secrets backup all ~/keychain-all.enc
keychain-secrets backup development ~/keychain-dev.enc
keychain-secrets restore ~/keychain-dev.enc

# Non-interactive (for automation)
export KEYCHAIN_BACKUP_PASSPHRASE='choose-a-strong-passphrase'
keychain-secrets backup wifi ~/keychain-wifi.enc
keychain-secrets restore ~/keychain-wifi.enc
```

### Add a new collection (example: wifi)

1. Add objects to `local/secrets/secrets-map.json` under `entries`.
2. Set values with `keychain-secrets set <ENV_VAR> <VALUE>`.
3. Use `keychain-secrets doctor wifi` to verify.

## SSH Key Backup

Use `ssh-keys-backup` for encrypted SSH key backups.

```bash
# See what would be included
ssh-keys-backup list

# Backup (interactive passphrase prompt)
ssh-keys-backup backup ~/ssh-keys.enc

# Backup (non-interactive)
export SSH_KEYS_BACKUP_PASSPHRASE='choose-a-strong-passphrase'
ssh-keys-backup backup ~/ssh-keys.enc

# Restore (safe by default, no overwrite)
ssh-keys-backup restore ~/ssh-keys.enc

# Restore and overwrite existing files
SSH_KEYS_RESTORE_OVERWRITE=1 ssh-keys-backup restore ~/ssh-keys.enc
```

## Security Model

- Private keys stay in `~/.ssh` and are never tracked.
- Personal identity (git name/email, npm registries, secrets map) lives in `local/` (gitignored).
- npm credentials are stored in a secrets backend (macOS Keychain or `pass`) and not in git.
- Secrets map entries are validated, including strict shell-safe `env_var` names.
- Run `./scripts/audit.sh` before commits.

## Repository Layout

```text
.dotfiles/
├── Brewfile
├── config/
│   └── cursor/
│       └── settings.json
├── git/
│   ├── .gitconfig
│   └── .gitignore_global
├── local/                          # gitignored, machine-specific
│   ├── git/
│   │   ├── .gitconfig-github
│   │   └── .gitconfig-azure-devops
│   ├── npm/
│   │   └── .npmrc-registries
│   └── secrets/
│       └── secrets-map.json
├── local.example/                  # tracked templates
│   ├── git/
│   │   ├── .gitconfig-github
│   │   └── .gitconfig-azure-devops
│   ├── npm/
│   │   └── .npmrc-registries
│   └── secrets/
│       └── secrets-map.json
├── npm/
│   └── .npmrc
├── scripts/
│   ├── audit.sh
│   ├── backup.sh
│   ├── bootstrap.sh
│   ├── dotfiles.sh
│   ├── install.sh
│   ├── keychain-secrets.sh
│   ├── lib/
│   │   ├── init.sh
│   │   ├── crypto.sh
│   │   ├── linker.sh
│   │   ├── packages.sh
│   │   └── platform.sh
│   ├── local-config.sh
│   ├── macos.sh
│   ├── packages.sh
│   ├── ssh-keys-backup.sh
│   └── symlinks.sh
├── ssh/
│   └── config
└── zsh/
    ├── .aliases
    ├── .exports
    ├── .functions
    ├── .platform-common
    ├── .platform-linux
    ├── .platform-macos
    ├── .zprofile
    └── .zshrc
```
