#!/usr/bin/env bash
# Bootstrap a fresh macOS workstation from this dotfiles repo.
#
# Usage on a brand-new Mac (no repo, no Homebrew):
#   curl -fsSL https://raw.githubusercontent.com/cplee/dotfiles/main/bin/bootstrap.sh | bash
#
# Usage when the repo is already cloned:
#   ./bin/bootstrap.sh
#
# Each phase is idempotent: re-running on an already-bootstrapped Mac is a
# no-op (or a no-op + a pull, in chezmoi's case). The script stops short of
# interactive steps (gh auth, 1Password SSH agent toggle) and prints them at
# the end as manual follow-ups.
#
# Override the source via env vars:
#   DOTFILES_REPO_URL   default: https://github.com/cplee/dotfiles.git
#   DOTFILES_REPO_DIR   default: $HOME/workspaces/dotfiles

set -euo pipefail

REPO_URL="${DOTFILES_REPO_URL:-https://github.com/cplee/dotfiles.git}"
REPO_DIR="${DOTFILES_REPO_DIR:-$HOME/workspaces/dotfiles}"
CHEZMOI_CONFIG="$HOME/.config/chezmoi/chezmoi.toml"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This bootstrap only runs on macOS."

ensure_xcode_clt() {
	if xcode-select -p >/dev/null 2>&1; then
		log "Xcode Command Line Tools already installed"
		return
	fi
	log "Installing Xcode Command Line Tools (a GUI prompt will appear)..."
	# Triggers the GUI installer; doesn't block until install completes.
	xcode-select --install >/dev/null 2>&1 || true
	log "Waiting for Xcode CLT install to finish..."
	until xcode-select -p >/dev/null 2>&1; do
		sleep 10
	done
	log "Xcode Command Line Tools installed"
}

ensure_homebrew() {
	if ! command -v brew >/dev/null 2>&1; then
		log "Installing Homebrew..."
		NONINTERACTIVE=1 /bin/bash -c \
			"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	else
		log "Homebrew already installed at $(command -v brew)"
	fi
	# Make brew available in this script's PATH regardless of arch.
	if [[ -x /opt/homebrew/bin/brew ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	elif [[ -x /usr/local/bin/brew ]]; then
		eval "$(/usr/local/bin/brew shellenv)"
	fi
	command -v brew >/dev/null 2>&1 || die "brew still not in PATH after install"
}

ensure_repo() {
	if [[ -d "$REPO_DIR/.git" ]]; then
		log "Repo already at $REPO_DIR; leaving as-is (run \`git pull\` yourself if you want updates)"
		return
	fi
	log "Cloning $REPO_URL into $REPO_DIR"
	mkdir -p "$(dirname "$REPO_DIR")"
	git clone "$REPO_URL" "$REPO_DIR"
}

ensure_brew_bundle() {
	log "Installing Brewfile contents..."
	brew bundle --file="$REPO_DIR/Brewfile"
}

ensure_chezmoi_config() {
	local expected="sourceDir = \"$REPO_DIR\""
	if [[ -f "$CHEZMOI_CONFIG" ]] && grep -qF "$expected" "$CHEZMOI_CONFIG"; then
		log "chezmoi config already points at $REPO_DIR"
		return
	fi
	mkdir -p "$(dirname "$CHEZMOI_CONFIG")"
	if [[ -f "$CHEZMOI_CONFIG" ]]; then
		local backup="$CHEZMOI_CONFIG.bak.$(date +%Y%m%d-%H%M%S)"
		warn "Existing chezmoi config differs; backing up to $backup"
		mv "$CHEZMOI_CONFIG" "$backup"
	fi
	log "Writing $CHEZMOI_CONFIG"
	cat > "$CHEZMOI_CONFIG" <<EOF
sourceDir = "$REPO_DIR"
EOF
}

ensure_chezmoi_apply() {
	log "Applying dotfiles with chezmoi..."
	chezmoi apply --verbose
}

print_next_steps() {
	printf '\n\033[1;32m✓ Bootstrap complete.\033[0m\n'
	cat <<EOF

Manual follow-ups (these need your hands on a browser / 1Password):

  1. Open 1Password → Settings → Developer → enable "Use the SSH agent",
     "Integrate with 1Password CLI", and add this to your shell init if not
     already there:
         SSH_AUTH_SOCK=~/Library/Group\\ Containers/2BUA8C4S2C.com.1password/t/agent.sock

  2. Authenticate the GitHub CLI:
         gh auth login          # choose SSH + 'Login with web browser'

  3. Switch this repo's remote to SSH so git pushes use the 1Password agent:
         git -C "$REPO_DIR" remote set-url origin git@github.com:cplee/dotfiles.git

  4. Restart your terminal so the new shell picks up starship and the rest.

EOF
}

main() {
	ensure_xcode_clt
	ensure_homebrew
	ensure_repo
	ensure_brew_bundle
	ensure_chezmoi_config
	ensure_chezmoi_apply
	print_next_steps
}

main "$@"
