# ============================================================
# termstrap bash fallback — terminal title only
# https://github.com/gunnarkw/termstrap
# Bash never becomes the managed shell; this file only keeps the terminal
# title (user@host: path) correct while an account's login shell is still
# bash — for example before an administrator runs `chsh`/`usermod -s` to
# switch it to Zsh, or on accounts that intentionally stay on bash. Once
# the login shell is Zsh, zsh/.zshrc's precmd takes over and this file is
# never sourced. Not a general-purpose bash configuration.
# ============================================================

case "$TERM" in
xterm*|screen*|tmux*)
  __termstrap_set_title() {
    local branch
    branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
    if [[ -n "$branch" ]]; then
      printf '\033]0;%s@%s: %s (%s)\007' \
        "$USER" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}" "$branch"
    else
      printf '\033]0;%s@%s: %s\007' \
        "$USER" "${HOSTNAME%%.*}" "${PWD/#$HOME/~}"
    fi
  }
  PROMPT_COMMAND="__termstrap_set_title${PROMPT_COMMAND:+; $PROMPT_COMMAND}"
  ;;
esac
