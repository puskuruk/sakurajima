# shellcheck shell=bash disable=SC1091
# Sakurajima zshrc

export PATH="$HOME/.local/bin:$PATH"

# History
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=200000
export SAVEHIST=200000
setopt hist_ignore_dups hist_reduce_blanks share_history inc_append_history

# Completion
autoload -Uz compinit
# Add custom completions path
fpath=("$HOME/.config/zsh/completions" $fpath)
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null || true
compinit -d "$ZSH_COMPDUMP" -C

# Keybindings
bindkey -e
bindkey '^R' history-incremental-search-backward

# Tools
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"

# Browser dev
export PATH="$HOME/workspace/depot_tools:$PATH"

# Client detection
detect_sakurajima_client() {
  local p="${PWD:A}" root="$HOME/workspace/clients/"
  if [[ "$p" == "${root}"* ]]; then
    local c="${${p#"${root}"}%%/*}"
    [[ -n "$c" && "$c" != "_archive" ]] && export SAKURAJIMA_CLIENT="$c" && return
  fi
  unset SAKURAJIMA_CLIENT
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd detect_sakurajima_client
add-zsh-hook chpwd detect_sakurajima_client

# Guards
[[ -x "$HOME/.local/bin/kubectl-guard" ]] && kubectl() { "$HOME/.local/bin/kubectl-guard" "$@"; }
[[ -x "$HOME/.local/bin/terraform-guard" ]] && terraform() { "$HOME/.local/bin/terraform-guard" "$@"; }

# Prompt
if command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi

# Focus/unfocus
focus() {
  local client="$1"
  [[ -z "$client" ]] && echo "Usage: focus <client>" >&2 && return 1
  skr focus "$client" || return 1
  local dir="$HOME/workspace/clients/$client"
  [[ "$client" == "personal" ]] && dir="$HOME/workspace/personal"
  [[ -d "$dir" ]] && cd "$dir" && echo "→ $dir"
  local key="$HOME/.ssh/keys/$client/id_ed25519"
  [[ -f "$key" ]] && { ssh-add -l 2>/dev/null | grep -q "$key" || ssh-add "$key" 2>/dev/null; }
}
unfocus() { skr unfocus; }

# Aliases
alias ll='eza -la --group-directories-first 2>/dev/null || ls -la'
alias gs='git status -sb'
alias ..='cd ..'
command -v bat >/dev/null 2>&1 && alias cat='bat'
command -v lazygit >/dev/null 2>&1 && alias lg='lazygit'

alias python='python3'

# Local overrides
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
