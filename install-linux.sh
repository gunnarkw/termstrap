#!/usr/bin/env bash
set -euo pipefail

PROFILE="${1:-core}"
MODE="${2:-all}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  echo "Usage: $0 [core|full] [all|system|user]" >&2
  echo "  profile  core (default): essential tools, suitable for agent accounts" >&2
  echo "           full: core plus btop, duf, shellcheck, dust, optional Conda" >&2
  echo "  mode     all (default): system packages, then per-user setup" >&2
  echo "           system: apt packages only (root or sudo required)" >&2
  echo "           user: per-user setup only (never uses sudo)" >&2
  exit 2
}

case "$PROFILE" in
  core|full) ;;
  *)
    echo "Unknown profile: $PROFILE" >&2
    usage
    ;;
esac

case "$MODE" in
  all|system|user) ;;
  *)
    echo "Unknown mode: $MODE" >&2
    usage
    ;;
esac

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This installer supports Linux only." >&2
  exit 1
fi

if [[ "$MODE" != "user" ]] && ! command -v apt-get >/dev/null 2>&1; then
  echo "System package installation supports Debian-based systems only." >&2
  exit 1
fi

core_packages=(
  bat
  build-essential
  ca-certificates
  curl
  fd-find
  fzf
  git
  jq
  micro
  ripgrep
  tldr
  tmux
  yq
  zsh
  zsh-autosuggestions
  zsh-syntax-highlighting
)

full_packages=(
  btop
  duf
  shellcheck
)

run_system() {
  echo "Installing $PROFILE profile system packages..."

  local -a apt_cmd
  if [[ "$(id -u)" -eq 0 ]]; then
    apt_cmd=(apt-get)
  elif command -v sudo >/dev/null 2>&1; then
    apt_cmd=(sudo apt-get)
  else
    echo "System mode requires root or sudo." >&2
    exit 1
  fi

  "${apt_cmd[@]}" update
  "${apt_cmd[@]}" install -y "${core_packages[@]}"

  if [[ "$PROFILE" == "full" ]]; then
    "${apt_cmd[@]}" install -y "${full_packages[@]}"
  fi
}

cargo_tools_missing() {
  if ! command -v eza >/dev/null 2>&1; then
    return 0
  fi
  if ! command -v delta >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$PROFILE" == "full" ]] && ! command -v dust >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

require_system_packages() {
  local -a missing=()
  local command_name

  for command_name in curl git zsh fzf jq micro rg tldr tmux yq; do
    if ! command -v "$command_name" >/dev/null 2>&1; then
      missing+=("$command_name")
    fi
  done

  if ! command -v bat >/dev/null 2>&1 &&
     ! command -v batcat >/dev/null 2>&1; then
    missing+=("bat")
  fi

  if ! command -v fd >/dev/null 2>&1 &&
     ! command -v fdfind >/dev/null 2>&1; then
    missing+=("fd-find")
  fi

  if [[ ! -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    missing+=("zsh-autosuggestions")
  fi

  if [[ ! -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    missing+=("zsh-syntax-highlighting")
  fi

  if [[ "$PROFILE" == "full" ]]; then
    for command_name in btop duf shellcheck; do
      if ! command -v "$command_name" >/dev/null 2>&1; then
        missing+=("$command_name")
      fi
    done
  fi

  if cargo_tools_missing && ! command -v cc >/dev/null 2>&1; then
    missing+=("build-essential")
  fi

  if (( ${#missing[@]} > 0 )); then
    echo "Missing system packages or commands: ${missing[*]}" >&2
    echo "User mode never uses sudo. Ask an administrator to run:" >&2
    echo "  ./install-linux.sh $PROFILE system" >&2
    echo "then rerun:" >&2
    echo "  ./install-linux.sh $PROFILE user" >&2
    exit 1
  fi
}

install_cargo_tool() {
  local command_name="$1"
  local crate_name="$2"

  if command -v "$command_name" >/dev/null 2>&1; then
    return
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    echo "Installing Rust toolchain for $command_name..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
      sh -s -- -y --profile minimal
    export PATH="$HOME/.cargo/bin:$PATH"
  fi

  echo "Installing $command_name..."
  cargo install --locked "$crate_name"
}

BACKUP_DIR=""

ensure_backup_dir() {
  local suffix=1

  if [[ -n "$BACKUP_DIR" ]]; then
    return
  fi

  BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"
  while [[ -e "$BACKUP_DIR" ]]; do
    BACKUP_DIR="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)-$suffix"
    suffix=$((suffix + 1))
  done
  mkdir -p "$BACKUP_DIR"
}

link_managed_file() {
  local source_file="$1"
  local destination="$2"
  local current_target managed_target

  if [[ -L "$destination" ]]; then
    current_target="$(readlink -f "$destination" 2>/dev/null || true)"
    managed_target="$(readlink -f "$source_file")"
    if [[ "$current_target" == "$managed_target" ]]; then
      return
    fi
  fi

  if [[ -e "$destination" || -L "$destination" ]]; then
    ensure_backup_dir
    cp -a "$destination" "$BACKUP_DIR/$(basename "$destination")"
    rm -f "$destination"
    echo "Existing $(basename "$destination") backed up to: $BACKUP_DIR/$(basename "$destination")"
  fi

  ln -s "$source_file" "$destination"
}

install_tmux_plugins() {
  local tpm_dir="$HOME/.tmux/plugins/tpm"
  local temporary_session=""

  if [[ ! -d "$tpm_dir/.git" ]]; then
    echo "Installing tmux plugin manager..."
    mkdir -p "$(dirname "$tpm_dir")"
    git clone --depth 1 https://github.com/tmux-plugins/tpm "$tpm_dir"
  fi

  # TPM reads plugin declarations from the active tmux server. Reload an
  # existing server, or create a short-lived session when none is running.
  if tmux list-sessions >/dev/null 2>&1; then
    tmux source-file "$HOME/.tmux.conf"
  else
    temporary_session="termstrap-install-$$"
    tmux -f "$HOME/.tmux.conf" new-session -d -s "$temporary_session"
  fi

  "$tpm_dir/bin/install_plugins"

  if [[ -n "$temporary_session" ]]; then
    tmux kill-session -t "$temporary_session" >/dev/null 2>&1 || true
  fi
}

report_login_shell() {
  local user_name login_shell zsh_path resolved_login resolved_zsh
  user_name="$(id -un)"
  login_shell="$(getent passwd "$user_name" | cut -d: -f7)"
  zsh_path="$(command -v zsh)"
  resolved_login="$(readlink -f "$login_shell" 2>/dev/null || echo "$login_shell")"
  resolved_zsh="$(readlink -f "$zsh_path")"

  if [[ "$resolved_login" != "$resolved_zsh" ]]; then
    echo
    echo "The login shell for $user_name is $login_shell, not Zsh."
    echo "Change it yourself with:"
    echo "  chsh -s $zsh_path"
    echo "or ask an administrator to run:"
    echo "  sudo usermod -s $zsh_path $user_name"
  fi
}

run_user() {
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  echo "Setting up $PROFILE profile for user $(id -un)..."

  require_system_packages

  mkdir -p "$HOME/.local/bin"

  if command -v batcat >/dev/null 2>&1 &&
     ! command -v bat >/dev/null 2>&1; then
    ln -sfn "$(command -v batcat)" "$HOME/.local/bin/bat"
  fi

  if command -v fdfind >/dev/null 2>&1 &&
     ! command -v fd >/dev/null 2>&1; then
    ln -sfn "$(command -v fdfind)" "$HOME/.local/bin/fd"
  fi

  install_cargo_tool eza eza
  install_cargo_tool delta git-delta

  if [[ "$PROFILE" == "full" ]]; then
    install_cargo_tool dust du-dust
  fi

  mkdir -p "$HOME/.config/termstrap"

  if [[ "$PROFILE" == "full" ]] &&
     [[ -x /opt/anaconda3/bin/conda || -x /opt/miniconda3/bin/conda ||
        -x "$HOME/anaconda3/bin/conda" || -x "$HOME/miniconda3/bin/conda" ]]; then
    touch "$HOME/.config/termstrap/enable-conda"
  else
    rm -f "$HOME/.config/termstrap/enable-conda"
  fi

  link_managed_file "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"
  link_managed_file "$REPO_DIR/zsh/.zprofile" "$HOME/.zprofile"
  link_managed_file "$REPO_DIR/bash/.bashrc" "$HOME/.bashrc"
  link_managed_file "$REPO_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
  install_tmux_plugins
  report_login_shell
}

case "$MODE" in
  system)
    run_system
    echo
    echo "System packages for the $PROFILE profile are installed."
    echo "Each user should now run:"
    echo "  ./install-linux.sh $PROFILE user"
    ;;
  user)
    run_user
    echo
    echo "Linux $PROFILE profile set up for $(id -un)."
    echo "Start a new shell with:"
    echo "  exec zsh"
    ;;
  all)
    run_system
    run_user
    echo
    echo "Linux $PROFILE profile installed."
    echo "Start a new shell with:"
    echo "  exec zsh"
    ;;
esac
