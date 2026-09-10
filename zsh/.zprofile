# User command-line tools
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  /opt/homebrew/bin
  /opt/homebrew/sbin
  /usr/local/Homebrew/bin
  /usr/local/Homebrew/sbin
  /home/linuxbrew/.linuxbrew/bin
  /home/linuxbrew/.linuxbrew/sbin
  /usr/local/sbin
  /usr/local/bin
  /usr/sbin
  /usr/bin
  /sbin
  /bin
  $path
)
export PATH

# Homebrew and Linuxbrew command directories are listed explicitly above.
# Do not evaluate `brew shellenv` in shared dotfiles: it injects completion
# directories owned by another account on multi-user machines, which compinit
# correctly rejects as insecure.

# OrbStack command-line tools and integration (when installed)
[[ -f "$HOME/.orbstack/shell/init.zsh" ]] &&
  source "$HOME/.orbstack/shell/init.zsh"

# Hermes Agent — ensure ~/.local/bin is on PATH
export PATH="$HOME/.local/bin:$PATH"
