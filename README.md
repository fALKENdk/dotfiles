# Dotfiles

Minimal cross-platform dotfiles with local/private data kept out of git.

## Quick Start

```bash
git clone git@github.com:<user>/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./scripts/install.sh
```

Restore from an existing backup during install:

```bash
./scripts/install.sh --restore backups/20260302-120000
```

Use `~/.dotfiles` to keep `$HOME` clean.

## Fresh macOS Bootstrap

For a brand-new Mac:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh)
```

This runs: Xcode CLT install, clone, package install, local config seed, symlinks and config generation, and macOS defaults.

Optional:

```bash
# Skip macOS defaults
bash <(curl -fsSL https://raw.githubusercontent.com/fALKENdk/dotfiles/main/scripts/bootstrap.sh) --skip-macos

# Restore backups during install
./scripts/install.sh --restore backups/20260302-120000

# Disable remote installers (Oh My Zsh / Cursor installer)
DOTFILES_ALLOW_REMOTE_INSTALLERS=0 ~/.dotfiles/scripts/install.sh
```

## Prerequisites

Packages are installed automatically via `brew bundle` from the `Brewfile`. Key dependencies:

- **Brewfile**: `git`, `jq`, `fd`, `rg` (ripgrep), `shellcheck`, `shfmt`, `tree`, `bats-core`
- **System**: `openssl`, `tar` (expected to be pre-installed on macOS and Linux)
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

Backups are stored in `backups/` (gitignored), organized into timestamped directories:

```
backups/
  20260302-120000/      # full backup (all three modules)
    local.enc
    secrets.enc
    ssh.enc
  20260301-150000/      # individual backup (one module)
    local.enc
```

One-shot backup:

```bash
dotfiles backup
dotfiles backup ~/external-backups
DOTFILES_BACKUP_PASSPHRASE='...' dotfiles backup
```

One-shot restore:

```bash
dotfiles restore                              # restores from latest timestamped directory in backups/
dotfiles restore backups/20260302-120000       # restores only the .enc files found in that directory
dotfiles restore --local backups/20260302-120000/local.enc
DOTFILES_BACKUP_PASSPHRASE='...' dotfiles restore
```

When run interactively, `backup` and `restore` prompt once for the passphrase and reuse it for all three modules. Override the default backup location with `DOTFILES_BACKUP_DIR`.

## Home Directory Policy

Use top-level links only for core shell/git files. Use XDG-style paths for runtime state and helper commands.

- Symlinks: `~/.zshrc`, `~/.zprofile`, `~/.gitignore_global`, `~/.gitconfig-*`, `~/.ssh/config`, `~/.agents`
- Generated files: `~/.gitconfig`, `~/.npmrc` (edit sources in `local/`, run `dotfiles symlinks` to regenerate)
- Platform marker: `~/.config/dotfiles/platform`
- Helper commands: `~/.local/bin`
- Homebrew shell init is handled by `zsh/.zprofile` (`eval "$(brew shellenv)"`)

## Node / npm

Node is managed by `nvm`. The `Brewfile` installs `nvm` (not `node`). For speed, `zsh/.zshenv` does **not** source `nvm.sh` (that adds ~1.5s per invocation); instead it reads `$NVM_DIR/alias/default` and prepends only that version's `bin` to `PATH`, so non-login subshells (IDE child processes, scripts) resolve `node`/`npm` without the startup cost. The full `nvm` shell function is sourced only in interactive shells via `zsh/.zshrc`.

Interactive shells also auto-switch node per project: a `chpwd` hook in `zsh/.zshrc` runs `nvm use` when you `cd` into a directory containing an `.nvmrc` (and `nvm use default` when you leave it). It only calls `nvm use` when the resolved version actually differs, so the per-`cd` cost is just a cheap upward `.nvmrc` lookup.

On macOS, login shells run `/etc/zprofile` → `path_helper -s`, which reorders `PATH` by putting `/etc/paths.d/*` entries first. `zsh/.zprofile` re-prepends nvm/dotnet/local/brew **after** `path_helper`, so nvm node wins in login shells too.

If a `brew node` is present (e.g. pulled in transitively by `bitwarden-cli`), nvm still shadows it because the nvm bin dir is prepended last. Set the default nvm version with:

```bash
nvm install --lts
nvm alias default 'lts/*'
```

## AI Agent Skills (`ai/agents`)

Agent config for `~/.agents` is version-controlled here. `~/.agents` is a symlink to `ai/agents` in this repo (created by `dotfiles symlinks`), so tools that manage skills (e.g. `npx skills`) write straight into the repo.

Only `ai/agents/.skill-lock.json` is tracked. The source-installed `ai/agents/skills/` directory is gitignored because it's fully reproducible from the lock file. On a new machine, after `dotfiles symlinks`, rehydrate the skills with:

```bash
npx skills install
```

Skills you author yourself go in `ai/agents/skills-custom/` (tracked). `dotfiles symlinks` links each one into `~/.agents/skills/<name>` so the agent runtime discovers them, and `npx skills` (which only prunes skills belonging to its known sources) leaves them alone.

## Platform Model

Platform selection happens at install time:

- `scripts/packages.sh` installs shared packages and platform-specific extras
- `scripts/symlinks.sh` writes `~/.config/dotfiles/platform` (read by install-time scripts)
- `zsh/.zshrc` loads `zsh/.platform-common`, which branches inline on `$OSTYPE`

On macOS, `./scripts/install.sh` runs `scripts/macos.sh` unless `--skip-macos` is used.

## Local Config (`local/`)

Machine-specific files live in `local/` (gitignored). Examples live in `local.example/` (tracked, reference only).

`dotfiles-local init` seeds only structural defaults:

- `local/git/.gitconfig` — base git settings (core, init, push, fetch)
- `local/npm/.npmrc` — base npm settings
- `local/secrets/secrets-map.json` — empty secret mappings

Additional files are opt-in. Copy from `local.example/` and customize:

- `local/git/.gitconfig-github` — GitHub identity (auto-detected by `dotfiles symlinks`)
- `local/git/.gitconfig-azure-devops` — Azure DevOps identity (auto-detected)
- `local/npm/.npmrc-registries` — scoped npm registries (appended to `~/.npmrc`)

When `dotfiles symlinks` runs, it generates `~/.gitconfig` from `local/git/.gitconfig` and appends `includeIf` blocks for each identity file found. Known providers (github, azure-devops) get conditional includes; other names get unconditional `[include]`.

```bash
dotfiles-local init
dotfiles-local list
```

Encrypted backup/restore:

```bash
dotfiles-local backup
dotfiles-local restore backups/20260302-120000/local.enc
dotfiles-local restore --overwrite backups/20260302-120000/local.enc

# Non-interactive
DOTFILES_BACKUP_PASSPHRASE='strong-passphrase' dotfiles-local backup
```

## Secrets and npm Credentials

npm credentials are never stored in tracked files.

- `dotfiles-secrets env` exports secrets into shell env
- `local/npm/.npmrc` references those environment variables
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
dotfiles-secrets set GITHUB_TOKEN "$(pbpaste)"   # GitHub PAT, e.g. to avoid `npx skills` rate limits
```

`GITHUB_TOKEN` is exported into interactive shells and is picked up by tools like `gh` and `npx skills update` (raising the GitHub API rate limit). Add the mapping to `local/secrets/secrets-map.json` (already gitignored) so the value is only ever stored in the Keychain, never in a tracked file.

Encrypted backup/restore:

```bash
dotfiles-secrets backup
dotfiles-secrets restore backups/20260302-120000/secrets.enc

# Non-interactive
DOTFILES_BACKUP_PASSPHRASE='choose-a-strong-passphrase' dotfiles-secrets backup
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
dotfiles-ssh backup
dotfiles-ssh restore backups/20260302-120000/ssh.enc
dotfiles-ssh restore --overwrite backups/20260302-120000/ssh.enc

# Non-interactive
DOTFILES_BACKUP_PASSPHRASE='choose-a-strong-passphrase' dotfiles-ssh backup
```

## Package Installation

Packages are defined in `Brewfile` and installed with `brew bundle` from `scripts/packages.sh`.
Linux additionally installs `pass`.

Cursor is installed through the official installer (unless disabled by `DOTFILES_ALLOW_REMOTE_INSTALLERS=0`), and CLI linking is attempted where supported.

## Testing

Integration tests use [BATS](https://github.com/bats-core/bats-core) and run in isolated temp directories.

```bash
bats tests/
```

## Security Notes

- Private keys stay in `~/.ssh` and are never tracked
- Personal identity and secret mappings live in `local/` (gitignored)
- Secrets are stored in Keychain/`pass`, not in git
- Run `./scripts/audit.sh` before commits
- On macOS, `security add-generic-password -w` passes the secret value as a CLI argument, which is briefly visible in the process list. This is a known limitation of the macOS `security` command.
