# Ryoku NixOS Zsh integration.
#
# Mirrors Ryoku's upstream Fish terminal environment while keeping the
# Starship configuration shell-independent and ~/.zshrc user-owned.

typeset -U path PATH

if [[ -d "$HOME/.local/bin" ]]; then
  path=("$HOME/.local/bin" $path)
fi

export GOBIN="$HOME/.local/bin"
export CARGO_INSTALL_ROOT="$HOME/.local"

export EDITOR="nvim"
export VISUAL="nvim"

if command -v ryoku-fastfetch >/dev/null 2>&1; then
  ryoku-fastfetch
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh --cmd cd)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi

ryoku_user_zsh="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/user.zsh"

if [[ -r "$ryoku_user_zsh" ]]; then
  source "$ryoku_user_zsh"
fi

unset ryoku_user_zsh
