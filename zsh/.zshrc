# Zinit is installed by ./install.sh. Do not clone repositories on every shell startup.
ZINIT_HOME="$HOME/.local/share/zinit/zinit.git"
if [[ -f "$ZINIT_HOME/zinit.zsh" ]]; then
    source "$ZINIT_HOME/zinit.zsh"
    autoload -Uz _zinit
    (( ${+_comps} )) && _comps[zinit]=_zinit

    # Fix widgets for Starship.
    if [[ "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select" || \
          "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select-wrapped" ]]; then
        zle -N zle-keymap-select ""
    fi

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
