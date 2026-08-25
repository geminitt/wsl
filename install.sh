#!/usr/bin/env bash
# Symlinks this repo's WSL-side dotfiles into $HOME.
# .wslconfig and wezterm/.wezterm.lua live on the Windows side and are
# intentionally not handled here — see README.md.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

link() {
  local src="$DOTFILES_DIR/$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && [ ! -L "$dst" ]; then
    mv "$dst" "$dst.bak"
    echo "Backed up existing $dst -> $dst.bak"
  fi
  ln -sfn "$src" "$dst"
  echo "Linked $dst -> $src"
}

link "zsh/.zshrc"                "$HOME/.zshrc"
link "zsh/.zshenv"                "$HOME/.zshenv"
link "zellij/config.kdl"          "$HOME/.config/zellij/config.kdl"
link "mise-en-place/config.toml"  "$HOME/.config/mise/config.toml"
