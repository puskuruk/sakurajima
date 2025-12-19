# 🏴 SAKURAJIMA ZSHRC — v5.0
# Deterministic, fast, client-aware, guard-wired.

# PATH invariants
export PATH="$HOME/.local/bin:$PATH"

# History (large, shared, sane)
export HISTFILE="$HOME/.zsh_history"
export HISTSIZE=200000
export SAVEHIST=200000
setopt hist_ignore_dups hist_reduce_blanks share_history inc_append_history

# Completion (fast + deterministic cache)
autoload -Uz compinit
ZSH_COMPDUMP="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"
mkdir -p "${ZSH_COMPDUMP:h}" 2>/dev/null || true
compinit -d "$ZSH_COMPDUMP" -C

# Keybindings
bindkey -e
bindkey '^R' history-incremental-search-backward

# Quality-of-life tools (optional)
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# --- ENV: Browser Dev ---
export PATH="$HOME/workspace/depot_tools:$PATH"

# --- ENV: Unified Version Manager (mise) ---
# Abstracted language management (Node, Go, Python, etc.)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# -------------------------------------------------------------------
# Client detection (NO hardcoding)
# Rule: if cwd is under ~/workspace/clients/<client>/..., SAKURAJIMA_CLIENT=<client>
# -------------------------------------------------------------------
detect_sakurajima_client() {
  local p="${PWD:A}"
  local root="$HOME/workspace/clients/"
  if [[ "$p" == ${root}* ]]; then
    local rest="${p#${root}}"
    local c="${rest%%/*}"
    if [[ -n "$c" && "$c" != "_archive" ]]; then
      export SAKURAJIMA_CLIENT="$c"
      return 0
    fi
  fi
  unset SAKURAJIMA_CLIENT
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd detect_sakurajima_client
add-zsh-hook chpwd detect_sakurajima_client

# -------------------------------------------------------------------
# Guards (wrap commands only if guard scripts exist)
# -------------------------------------------------------------------
if [[ -x "$HOME/.local/bin/kubectl-guard" ]]; then
  kubectl() { "$HOME/.local/bin/kubectl-guard" "$@"; }
fi
if [[ -x "$HOME/.local/bin/terraform-guard" ]]; then
  terraform() { "$HOME/.local/bin/terraform-guard" "$@"; }
fi

# -------------------------------------------------------------------
# Starship prompt
# -------------------------------------------------------------------
if command -v starship >/dev/null 2>&1; then
  export STARSHIP_CONFIG="$HOME/.config/starship.toml"
  eval "$(starship init zsh)"
fi

# Aliases (minimal, deterministic)
alias ll='eza -la --group-directories-first 2>/dev/null || ls -la'
alias gs='git status -sb'
alias ..='cd ..'

# Power Aliases
if command -v bat >/dev/null 2>&1; then alias cat='bat'; fi
if command -v lazygit >/dev/null 2>&1; then alias lg='lazygit'; fi

# Local Overrides (ignored by git)
[[ -f "$HOME/.zshrc.local" ]] && source "$HOME/.zshrc.local"
