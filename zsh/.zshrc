# Zinit is installed by ./install.sh. Do not clone repositories on every shell startup.
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    zinit light-mode for \
        zdharma-continuum/zinit-annex-as-monitor \
        zdharma-continuum/zinit-annex-bin-gem-node \
        zdharma-continuum/zinit-annex-patch-dl \
        zdharma-continuum/zinit-annex-rust

    zinit wait lucid light-mode for \
        atinit"zicompinit; zicdreplay" \
            zdharma-continuum/fast-syntax-highlighting \
        atload"_zsh_autosuggest_start" \
            zsh-users/zsh-autosuggestions \
        blockf atpull"zinit creinstall -q ." \
            zsh-users/zsh-completions

    # zsh-vi-mode initializes after this file. Rebind fzf widgets afterward.
    # Use `command -v` here: zsh-vi-mode locally shadows the special $commands hash.
    typeset -ga zvm_after_init_commands
    zvm_after_init_commands+=('command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)')
    zinit depth"1" light-mode for \
        jeffreytse/zsh-vi-mode
else
    print -P '%F{yellow}[zsh] Zinit not installed; run ~/wsl/install.sh to set up the shell.%f'
fi

# History.
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS

# Shared CLI initialization. Guard each command so partial installs stay usable.
if (( $+commands[mise] )); then
    eval "$(mise activate zsh)"
fi
if (( $+commands[zoxide] )); then
    eval "$(zoxide init zsh)"
fi
if (( $+commands[fzf] )); then
    source <(fzf --zsh)
fi
if (( $+commands[starship] )); then
    eval "$(starship init zsh)"
fi
