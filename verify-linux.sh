#!/usr/bin/env bash
set -uo pipefail

PROFILE="${1:-core}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
failures=0

case "$PROFILE" in
  core|full)
    ;;
  *)
    echo "Usage: $0 [core|full]" >&2
    exit 2
    ;;
esac

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

system_hint="ask an administrator to run: ./install-linux.sh $PROFILE system"
user_hint="run: ./install-linux.sh $PROFILE user"

check_command() {
  local command_name="$1"
  local hint="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    printf 'PASS  %-24s %s\n' "$command_name" "$(command -v "$command_name")"
  else
    printf 'FAIL  %-24s missing; %s\n' "$command_name" "$hint"
    failures=$((failures + 1))
  fi
}

check_file() {
  local description="$1"
  local file_path="$2"
  local hint="$3"

  if [[ -e "$file_path" ]]; then
    printf 'PASS  %-24s %s\n' "$description" "$file_path"
  else
    printf 'FAIL  %-24s missing: %s; %s\n' "$description" "$file_path" "$hint"
    failures=$((failures + 1))
  fi
}

echo "Verifying Linux $PROFILE profile..."
echo

apt_commands=(
  fzf
  git
  jq
  micro
  rg
  tldr
  tmux
  yq
  zsh
)

user_commands=(
  bat
  delta
  eza
  fd
)

full_apt_commands=(
  btop
  duf
  shellcheck
)

for command_name in "${apt_commands[@]}"; do
  check_command "$command_name" "$system_hint"
done

for command_name in "${user_commands[@]}"; do
  check_command "$command_name" "$user_hint"
done

if [[ "$PROFILE" == "full" ]]; then
  for command_name in "${full_apt_commands[@]}"; do
    check_command "$command_name" "$system_hint"
  done
  check_command "dust" "$user_hint"
fi

zshrc_source="$REPO_DIR/zsh/.zshrc"
zshrc_expected="$(readlink -f "$zshrc_source" 2>/dev/null || true)"
zshrc_actual="$(readlink -f "$HOME/.zshrc" 2>/dev/null || true)"

if [[ -L "$HOME/.zshrc" && -n "$zshrc_expected" &&
      "$zshrc_actual" == "$zshrc_expected" ]]; then
  printf 'PASS  %-24s -> %s\n' ".zshrc symlink" "$zshrc_expected"
else
  printf 'FAIL  %-24s not a symlink to %s; %s\n' \
    ".zshrc symlink" "$zshrc_source" "$user_hint"
  failures=$((failures + 1))
fi

for managed_file in "zsh/.zprofile:$HOME/.zprofile" "bash/.bashrc:$HOME/.bashrc" "tmux/.tmux.conf:$HOME/.tmux.conf"; do
  source_file="$REPO_DIR/${managed_file%%:*}"
  destination="${managed_file#*:}"
  expected="$(readlink -f "$source_file" 2>/dev/null || true)"
  actual="$(readlink -f "$destination" 2>/dev/null || true)"
  if [[ -L "$destination" && -n "$expected" && "$actual" == "$expected" ]]; then
    printf 'PASS  %-24s -> %s\n' "$(basename "$destination") symlink" "$expected"
  else
    printf 'FAIL  %-24s not a symlink to %s; %s\n' "$(basename "$destination") symlink" "$source_file" "$user_hint"
    failures=$((failures + 1))
  fi
done

if [[ -x "$HOME/.tmux/plugins/tpm/tpm" ]]; then
  printf 'PASS  %-24s %s\n' "TPM" "$HOME/.tmux/plugins/tpm/tpm"
else
  printf 'FAIL  %-24s missing; %s\n' "TPM" "$user_hint"
  failures=$((failures + 1))
fi

for plugin_name in tmux-resurrect tmux-continuum tmux-yank tmux-cpu extrakto tmux-open; do
  if [[ -d "$HOME/.tmux/plugins/$plugin_name" ]]; then
    printf 'PASS  %-24s %s\n' "plugin: $plugin_name" "$HOME/.tmux/plugins/$plugin_name"
  else
    printf 'FAIL  %-24s missing; %s\n' "plugin: $plugin_name" "$user_hint"
    failures=$((failures + 1))
  fi
done

if command -v tmux >/dev/null 2>&1 && tmux -f "$HOME/.tmux.conf" -L termstrap-verify start-server \; show-options -g >/dev/null 2>&1; then
  printf 'PASS  %-24s valid\n' "tmux config"
  tmux -L termstrap-verify kill-server >/dev/null 2>&1 || true
else
  printf 'FAIL  %-24s invalid\n' "tmux config"
  failures=$((failures + 1))
fi

check_file "autosuggestions" \
  "/usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$system_hint"
check_file "syntax highlighting" \
  "/usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  "$system_hint"

zsh_bin="$(command -v zsh || true)"

if [[ -n "$zsh_bin" ]]; then
  if "$zsh_bin" -n "$HOME/.zshrc"; then
    printf 'PASS  %-24s valid\n' "Zsh syntax"
  else
    printf 'FAIL  %-24s invalid; fix %s\n' "Zsh syntax" "$zshrc_source"
    failures=$((failures + 1))
  fi

  if "$zsh_bin" -ic 'alias sshk' >/dev/null 2>&1; then
    printf 'PASS  %-24s available\n' "sshk alias"
  else
    printf 'FAIL  %-24s unavailable; %s\n' "sshk alias" "$user_hint"
    failures=$((failures + 1))
  fi

  login_shell="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)"
  resolved_login="$(readlink -f "$login_shell" 2>/dev/null || echo "$login_shell")"
  resolved_zsh="$(readlink -f "$zsh_bin")"

  if [[ "$resolved_login" == "$resolved_zsh" ]]; then
    printf 'PASS  %-24s %s\n' "Login shell" "$login_shell"
  else
    printf 'WARN  %-24s %s\n' "Login shell" "$login_shell"
    printf '      Change with: chsh -s %s\n' "$zsh_bin"
    printf '      or (administrator): sudo usermod -s %s %s\n' \
      "$zsh_bin" "$(id -un)"
  fi
else
  printf 'FAIL  %-24s zsh missing; skipped syntax, sshk, and shell checks\n' \
    "Zsh checks"
  failures=$((failures + 1))
fi

bash_bin="$(command -v bash || true)"
bashrc_source="$REPO_DIR/bash/.bashrc"

if [[ -n "$bash_bin" ]]; then
  if "$bash_bin" -n "$HOME/.bashrc"; then
    printf 'PASS  %-24s valid\n' "Bash syntax"
  else
    printf 'FAIL  %-24s invalid; fix %s\n' "Bash syntax" "$bashrc_source"
    failures=$((failures + 1))
  fi
else
  printf 'FAIL  %-24s bash missing; skipped syntax check\n' "Bash checks"
  failures=$((failures + 1))
fi

echo

if (( failures > 0 )); then
  echo "Verification failed with $failures problem(s)."
  echo "For apt packages, $system_hint"
  echo "For user-level tools and links, $user_hint"
  exit 1
fi

echo "Verification passed."
