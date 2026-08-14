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

required=(bat eza fd fzf git delta jq micro rg tldr tmux yq)
if [[ "$profile" == "full" ]]; then
  required+=(btop dust duf shellcheck)
fi

failed=0
for tool in "${required[@]}"; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%-12s %s\n' "$tool" "installed"
  else
    printf '%-12s %s\n' "$tool" "MISSING"
    failed=1
  fi
done

for file in "$HOME/.zshrc" "$HOME/.zprofile" "$HOME/.tmux.conf"; do
  if [[ -L "$file" && -e "$file" ]]; then
    printf '%-12s %s\n' "$(basename "$file")" "linked"
  else
    printf '%-12s %s\n' "$(basename "$file")" "NOT LINKED"
    failed=1
  fi
done

if [[ ! -x "$HOME/.tmux/plugins/tpm/tpm" ]]; then
  echo "TPM is missing." >&2
  failed=1
fi

for plugin_name in tmux-resurrect tmux-continuum tmux-yank tmux-cpu extrakto tmux-open; do
  if [[ -d "$HOME/.tmux/plugins/$plugin_name" ]]; then
    printf '%-20s %s\n' "plugin: $plugin_name" "installed"
  else
    printf '%-20s %s\n' "plugin: $plugin_name" "MISSING"
    failed=1
  fi
done

if command -v tmux >/dev/null 2>&1; then
  if tmux -f "$HOME/.tmux.conf" -L termstrap-verify start-server \; show-options -g >/dev/null 2>&1; then
    tmux -L termstrap-verify kill-server >/dev/null 2>&1 || true
  else
    echo "tmux configuration validation failed." >&2
    failed=1
  fi
fi

if ! /bin/zsh -n "$HOME/.zshrc" "$HOME/.zprofile"; then
  echo "Zsh syntax validation failed." >&2
  failed=1
fi

if [[ ! -s "$HOME/.nvm/nvm.sh" ]]; then
  echo "NVM is missing." >&2
  failed=1
fi

configured_profile="$(cat "$HOME/.config/termstrap/profile" 2>/dev/null || true)"
if [[ "$configured_profile" != "$profile" ]]; then
  echo "Profile marker does not match requested profile." >&2
  failed=1
fi

if [[ "$failed" -ne 0 ]]; then
  echo "Validation failed." >&2
  exit 1
fi

echo "Validation passed for profile: $profile"
