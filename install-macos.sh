#!/usr/bin/env bash
set -euo pipefail

profile="${1:-}"
if [[ "$profile" == "agent" ]]; then
  echo "Note: the 'agent' profile is now called 'core'." >&2
  profile="core"
fi
if [[ "$profile" != "full" && "$profile" != "core" ]]; then
  echo "Usage: $0 core|full" >&2
  exit 2
fi

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installer supports macOS only." >&2
  exit 1
fi

if ! xcode-select -p >/dev/null 2>&1; then
  echo "Apple Command Line Tools are required. Run: xcode-select --install" >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  eval "$(brew shellenv)"
fi

echo "Installing core command-line tools..."
brew bundle --file "$repo_dir/Brewfile.core"
if [[ "$profile" == "full" ]]; then
  echo "Installing full-profile tools..."
  brew bundle --file "$repo_dir/Brewfile.full"
fi

backup_dir="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
backup_suffix=1
while [[ -e "$backup_dir" ]]; do
  backup_dir="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)-$backup_suffix"
  backup_suffix=$((backup_suffix + 1))
done
backup_created=false
for managed_file in \
  "zsh/.zshrc:$HOME/.zshrc" \
  "zsh/.zprofile:$HOME/.zprofile" \
  "tmux/.tmux.conf:$HOME/.tmux.conf"; do
  source_file="$repo_dir/${managed_file%%:*}"
  destination="${managed_file#*:}"
  target="$(basename "$destination")"

  if [[ -e "$destination" || -L "$destination" ]]; then
    current_target="$(readlink "$destination" 2>/dev/null || true)"
    if [[ "$current_target" != "$source_file" ]]; then
      mkdir -p "$backup_dir"
      cp -a "$destination" "$backup_dir/$target"
      backup_created=true
      rm -f "$destination"
    fi
  fi

  if [[ ! -L "$destination" ]]; then
    ln -s "$source_file" "$destination"
  fi
done

tpm_dir="$HOME/.tmux/plugins/tpm"
if [[ ! -d "$tpm_dir/.git" ]]; then
  echo "Installing tmux plugin manager..."
  mkdir -p "$(dirname "$tpm_dir")"
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
fi

temporary_tmux_session=""
if tmux list-sessions >/dev/null 2>&1; then
  tmux source-file "$HOME/.tmux.conf"
else
  temporary_tmux_session="termstrap-install-$$"
  tmux -f "$HOME/.tmux.conf" new-session -d -s "$temporary_tmux_session"
fi

"$tpm_dir/bin/install_plugins"

if [[ -n "$temporary_tmux_session" ]]; then
  tmux kill-session -t "$temporary_tmux_session" >/dev/null 2>&1 || true
fi

if [[ "$backup_created" == true ]]; then
  echo "Existing shell files backed up to: $backup_dir"
fi

config_dir="$HOME/.config/termstrap"
mkdir -p "$config_dir"
if [[ "$profile" == "full" ]]; then
  touch "$config_dir/enable-conda"
else
  rm -f "$config_dir/enable-conda"
fi
printf '%s\n' "$profile" > "$config_dir/profile"

if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  echo "Installing NVM..."
  nvm_version="v0.40.3"
  curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh" | bash
fi

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
source "$NVM_DIR/nvm.sh"
nvm install 22
nvm alias default 22

git config --global core.editor micro
git config --global core.pager delta
git config --global interactive.diffFilter 'delta --color-only'
git config --global delta.navigate true
git config --global delta.side-by-side false
git config --global merge.conflictStyle zdiff3

"$repo_dir/verify-macos.sh" "$profile"

echo
echo "Installation complete for profile: $profile"
echo "Start a fresh login shell with: exec zsh -l"
