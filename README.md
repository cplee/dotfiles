# dotfiles

Personal MacBook workstation setup. Apps installed via Homebrew, dotfiles managed by [chezmoi](https://chezmoi.io), commits signed via the 1Password SSH agent.

## Quick start (fresh Mac)

```bash
curl -fsSL https://raw.githubusercontent.com/cplee/dotfiles/main/bin/bootstrap.sh | bash
```

[`bin/bootstrap.sh`](bin/bootstrap.sh) handles Xcode CLT → Homebrew → clone → `brew bundle` → chezmoi config → `chezmoi apply`. Each phase is idempotent, so re-running is safe.

After it finishes, four manual follow-ups:

1. **1Password** → Settings → Developer → enable "Use the SSH agent".
2. `gh auth login` (choose SSH + "Login with web browser").
3. Switch the remote to SSH so pushes go through the 1Password agent:
   ```bash
   git -C ~/workspaces/dotfiles remote set-url origin git@github.com:cplee/dotfiles.git
   ```
4. Restart your terminal.

## Layout

| Path | Purpose |
|------|---------|
| [`Brewfile`](Brewfile) | Apps + CLIs installed by `brew bundle` |
| [`bin/bootstrap.sh`](bin/bootstrap.sh) | Fresh-Mac bootstrap script |
| `dot_gitconfig` → `~/.gitconfig` | Git config with 1Password SSH commit signing |
| `dot_zshrc` → `~/.zshrc` | starship prompt init |
| `.chezmoiignore` | Repo-infra files excluded from `$HOME` install |
| [`CLAUDE.md`](CLAUDE.md) | Guidance for Claude Code sessions |
| [`docs/`](docs/) | Per-topic setup runbooks (e.g. [yubikey-setup.md](docs/yubikey-setup.md)) |

chezmoi's source directory is this repo (`~/workspaces/dotfiles`), wired up via `~/.config/chezmoi/chezmoi.toml`:

```toml
sourceDir = "/Users/cplee/workspaces/dotfiles"
```

That config file is user-local and not in the repo (the bootstrap writes it).

## Daily workflow

```bash
chezmoi diff                 # preview what apply would change
chezmoi apply                # install source → $HOME
chezmoi add ~/.some/file     # start tracking a file currently in $HOME
chezmoi edit ~/.some/file    # edit the managed source of a file
chezmoi re-add               # pull in-place edits from $HOME back to the source
```

After `chezmoi add`, commit the new file in this repo. The file is already at its destination, so no `chezmoi apply` is needed.

## Override defaults

For a fork, two env vars steer the bootstrap:

```bash
DOTFILES_REPO_URL=https://github.com/yourname/dotfiles.git \
DOTFILES_REPO_DIR=$HOME/code/dotfiles \
  bash bootstrap.sh
```

## Archive

The pre-2020 [Prezto](https://github.com/sorin-ionescu/prezto)-fork history that used to live on `master` is preserved at [`archive/master-2020`](https://github.com/cplee/dotfiles/tree/archive/master-2020). Not used by the current setup.
