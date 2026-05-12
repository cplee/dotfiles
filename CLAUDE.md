# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

Tooling to set up and manage MacBook workstations — installing apps via Homebrew, applying dotfiles via [chezmoi](https://chezmoi.io), and keeping multiple Macs in sync. Designed for a freshly-imaged Mac with no assumptions beyond what Apple ships (and Homebrew, once bootstrapped).

## Layout

```
Brewfile                          Homebrew bundle (apps + CLIs + chezmoi + gh + font)
dot_gitconfig                     → ~/.gitconfig    (git SSH signing via 1Password)
dot_zshrc                         → ~/.zshrc
.chezmoiignore                    Excludes Brewfile / CLAUDE.md / .claude from $HOME install
.claude/skills/sync-dotfiles/     Skill that wraps the chezmoi workflow
```

chezmoi's source-dir naming convention: a file named `dot_<x>` installs to `~/.<x>`. Subdir example: `dot_config/git/config` → `~/.config/git/config`. Anything not prefixed accordingly is ignored at apply time (and the obvious non-dotfiles are also covered by `.chezmoiignore`).

The source directory is **this repo** (`~/workspaces/dotfiles`). That's wired up via `~/.config/chezmoi/chezmoi.toml`:

```toml
sourceDir = "/Users/cplee/workspaces/dotfiles"
```

That file is user-local — it is NOT in this repo (would be circular). On a fresh Mac it gets recreated by hand or by the bootstrap step that points chezmoi at this clone.

## chezmoi workflow

| Action                       | Command                          |
|------------------------------|----------------------------------|
| Preview what apply will do   | `chezmoi diff`                   |
| Apply source → $HOME         | `chezmoi apply`                  |
| Add a new dotfile from $HOME | `chezmoi add ~/.path/to/file`    |
| Edit a managed file's source | `chezmoi edit ~/.path/to/file`   |
| Re-sync after editing in $HOME directly | `chezmoi re-add`      |
| Check repo state             | `chezmoi managed` / `chezmoi status` / `chezmoi doctor` |

`chezmoi add` copies the destination file into the source dir with the correct `dot_`-style name, replacing any previous tracking. `chezmoi edit` opens the source file (not the destination) — edits propagate to $HOME on the next `apply`. `chezmoi re-add` is for when you edited the destination file directly and want to push that back into the source.

After adding a new file, also confirm `.chezmoiignore` doesn't need an update for any sibling files you don't want managed.

## Brewfile workflow

The `Brewfile` is a [Homebrew Bundle](https://github.com/Homebrew/homebrew-bundle) manifest. Casks: `ghostty`, `zed`, `spotify`, `font-hack-nerd-font`. Brews: `yazi`, `mise`, `starship`, `chezmoi`, `gh`.

- Install everything listed: `brew bundle --file=Brewfile`
- Regenerate from currently-installed set: `brew bundle dump --file=Brewfile --force` (review the diff before committing — `--force` overwrites in place)
- Check for drift: `brew bundle check --file=Brewfile`

Keep entries grouped by type (casks block, then brews block).

## Environment assumptions

- SSH agent is provided by **1Password** (not the system `ssh-agent`). `dot_gitconfig` references the 1Password signer at `/Applications/1Password.app/Contents/MacOS/op-ssh-sign`. Don't swap in a vanilla `ssh-agent` / `~/.ssh/id_*` setup without checking first.
- The SSH signing key value in `dot_gitconfig` is the **public** key blob — safe as plaintext, no need to fetch via `op://` template at apply time. If a private value ever needs to land in a managed file, prefer `{{ onepasswordRead "op://..." }}` templating (rename the file to `<name>.tmpl`).
- The Nerd Font (Hack) is required by starship glyphs and Ghostty's default rendering.

## Bootstrapping a fresh Mac

Rough sequence (not yet captured as a script):

1. Install Homebrew (one-liner from brew.sh).
2. Clone this repo to `~/workspaces/dotfiles`.
3. `brew bundle --file=~/workspaces/dotfiles/Brewfile` — installs chezmoi, gh, font, the rest.
4. Write `~/.config/chezmoi/chezmoi.toml` with `sourceDir = "..."` pointing at the clone.
5. `chezmoi apply` to install dotfiles.
6. `gh auth login` if working with GitHub.

If/when this grows large enough, the bootstrap belongs in its own `bin/bootstrap.sh`.
