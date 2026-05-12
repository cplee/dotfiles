---
name: sync-dotfiles
description: Apply or update dotfiles in $HOME using chezmoi. Use when the user wants to "sync dotfiles", "apply dotfiles", "update my dotfiles", track a new file under chezmoi, set up a fresh Mac from this repo, or run any chezmoi workflow against this repo.
---

# Sync dotfiles (chezmoi)

This repo manages a MacBook workstation. Dotfiles live at the repo root with chezmoi's `dot_` prefix convention (`dot_zshrc` → `~/.zshrc`, `dot_config/git/config` → `~/.config/git/config`, etc.). The repo IS chezmoi's source directory, wired up via `~/.config/chezmoi/chezmoi.toml`'s `sourceDir = "/Users/cplee/workspaces/dotfiles"`.

## Common actions

| User intent                              | Command                            |
|------------------------------------------|------------------------------------|
| Preview changes apply would make         | `chezmoi diff`                     |
| Apply source → `$HOME`                   | `chezmoi apply`                    |
| Start tracking a file currently in $HOME | `chezmoi add ~/.path/to/file`      |
| Edit a managed file's source             | `chezmoi edit ~/.path/to/file`     |
| Pull back edits made directly in $HOME   | `chezmoi re-add`                   |
| Sanity-check repo + system state         | `chezmoi doctor` / `chezmoi managed` |

`chezmoi apply` is idempotent; running it when everything is in sync is a no-op (and `chezmoi diff` will be empty).

## Tracking a new dotfile

When the user wants to add a new file (e.g. `~/.config/ghostty/config`):

1. `chezmoi add ~/.config/ghostty/config` — copies the file into the source dir with the right `dot_config/ghostty/config` naming.
2. Check `chezmoi managed` to confirm it's tracked.
3. If the file is secret-bearing, consider templating it (rename to `<name>.tmpl` and reference 1Password via `{{ onepasswordRead "op://..." }}`).
4. `git add -A && git commit` to persist in the repo. Skip `chezmoi apply` — the file is already at its destination, that's where it was added from.

## After running

- Surface the `chezmoi diff` / `chezmoi apply` output. If `apply` printed nothing, say so explicitly.
- If the user expected a particular file to change, run `chezmoi status <file>` and report whether chezmoi sees a divergence.
- If a managed file in $HOME has drifted from the source (someone edited the destination directly), `chezmoi re-add` pulls it back into the repo — flag this and ask before doing it, since it overwrites the tracked source.

## Out of scope

- Installing Homebrew packages — that's `brew bundle --file=Brewfile` at repo root.
- Mac bootstrap from zero (Xcode CLT, Homebrew install, writing `~/.config/chezmoi/chezmoi.toml`). When that script lands, it'll be at `bin/bootstrap.sh` — don't improvise one inside this skill.
- Switching to a different dotfiles tool (stow, nix-darwin, etc.). That's an architectural decision, not a sync task.
