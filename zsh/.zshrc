# ============================================================
# termstrap shared zsh configuration
# https://github.com/gunnarkw/termstrap
# Machine-specific additions belong in ~/.zshrc.local
# ============================================================

# Paths
typeset -U path PATH
path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.npm-global/bin"
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

# Homebrew and Linuxbrew command directories are listed explicitly above for
# login and non-login shells. Avoid `brew shellenv` because it imports shared
# completion paths that are unsafe across accounts.

# Default terminal editor
export EDITOR="micro"
export VISUAL="micro"

# Prompt
PROMPT='%F{green}%n@%m%f: %F{blue}%~%f > '

# Shell behaviour
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
unsetopt CORRECT CORRECT_ALL
unsetopt NOMATCH

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000
setopt APPEND_HISTORY
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS

# Completion
autoload -Uz compinit
compinit -d "$HOME/.zcompdump"
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*'
zstyle ':completion:*' menu select
bindkey '^I' expand-or-complete-prefix

# Fuzzy finder
[[ -f "$HOME/.fzf.zsh" ]] && source "$HOME/.fzf.zsh"

# Git-aware terminal title
autoload -Uz vcs_info
zstyle ':vcs_info:git:*' formats '%b '
precmd() {
  vcs_info
  if [[ -n "$vcs_info_msg_0_" ]]; then
    print -Pn "\e]0;%n@%m: %~ ($vcs_info_msg_0_)\a"
  else
    print -Pn "\e]0;%n@%m: %~\a"
  fi
}

# Conda: load lazily when enabled by the installer.
if [[ -f "$HOME/.config/termstrap/enable-conda" ]]; then
  conda() {
    local conda_executable candidate

    for candidate in \
      /opt/anaconda3/bin/conda \
      /opt/miniconda3/bin/conda \
      "$HOME/anaconda3/bin/conda" \
      "$HOME/miniconda3/bin/conda"; do
      if [[ -x "$candidate" ]]; then
        conda_executable="$candidate"
        break
      fi
    done

    if [[ -z "${conda_executable:-}" ]]; then
      print -u2 "Conda was not found"
      return 127
    fi

    unfunction conda
    eval "$("$conda_executable" shell.zsh hook)"
    conda "$@"
  }
fi

# NVM: load only when Node tooling is first used.
export NVM_DIR="$HOME/.nvm"
load_nvm() {
  unfunction nvm node npm npx corepack load_nvm 2>/dev/null
  if [[ -s "$NVM_DIR/nvm.sh" ]]; then
    source "$NVM_DIR/nvm.sh"
  else
    print -u2 "NVM is not installed at $NVM_DIR"
    return 127
  fi
}
for _node_command in nvm node npm npx corepack; do
  eval "${_node_command}() { load_nvm && ${_node_command} \"\$@\"; }"
done
unset _node_command

# File listing, viewing, and editing
alias ls='eza --color=always --icons'
alias ll='eza -l --color=always --icons --git'
alias la='eza -la --color=always --icons --git'
alias lt='eza --tree --level=2 --color=always --icons'
alias cat='bat --paging=never'
alias m='micro'

# Git
alias gs='git status'
alias gp='git pull'

# Python
alias venv='source venv/bin/activate'
alias pyserve='python3 -m http.server'
alias pylint='flake8 .'
alias pyfmt='black .'
alias pysort='isort .'

# Docker
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dps='docker ps'
alias dex='docker exec -it'

# AWS
alias aws-profile='export AWS_PROFILE='
alias s3ls='aws s3 ls'
alias ec2ls='aws ec2 describe-instances --query "Reservations[].Instances[].InstanceId" --output table'

# Node
alias npmi='npm install'
alias npms='npm start'
alias npmb='npm run build'
alias dev='npm run dev'

# SSH
alias sshk='ssh -o PreferredAuthentications=publickey -o PasswordAuthentication=no'

# Machine-specific and personal configuration that should survive updates.
# Loaded before the plugins so added widgets and bindings get highlighted.
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"

# Zsh autosuggestions
for plugin in \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -f "$plugin" ]]; then
    source "$plugin"
    break
  fi
done
unset plugin

# Syntax highlighting must remain last.
for plugin in \
  /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -f "$plugin" ]]; then
    source "$plugin"
    break
  fi
done
unset plugin

# Added by cua-driver-rs installer — see https://github.com/trycua/cua
export PATH="/Users/gunnarwold/.local/bin:$PATH"
