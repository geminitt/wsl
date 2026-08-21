<div align="center">

# WSL

[![WSL](https://img.shields.io/badge/WSL2-Ubuntu--26.04-498AF2?style=for-the-badge)](https://ubuntu.com/wsl)
[![Version](https://img.shields.io/badge/VERSION-0.1.0-A19654?style=for-the-badge)](https://github.com/geminitt/wsl)
[![License](https://img.shields.io/badge/LICENSE-MIT-6B7F4E?style=for-the-badge)](./LICENSE)

**Workflow for AI**

</div>

---

## Prerequisites

| Requirement | Notes |
|---|---|
| Windows 11 | WSL2 support required |
| WSL-2 | `wsl --set-default-version 2` |
| NVIDIA Driver ≥ 525 | For CUDA passthrough into WSL |
| Docker Desktop | Enable WSL integration in settings |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Windows Host                                           │
│  NVIDIA Driver (CUDA passthrough)  ·  Docker Desktop    │
└─────────────────────────┬───────────────────────────────┘
                          │ WSL2
┌─────────────────────────▼───────────────────────────────┐
│  1. APT — system layer                                  │
│     Build tools · system libs · git · curl              │
├─────────────────────────────────────────────────────────┤
│  2. mise — tooling layer                                │
│     Dev runtimes · ripgrep · bat · fzf · zellij · nvim  │
├─────────────────────────────────────────────────────────┤
│  3. pixi — AI/ML layer (per-project)                    │
│     PyTorch · transformers · CUDA runtime               │
├─────────────────────────────────────────────────────────┤
│  Shell: Zsh + Zinit + Starship                          │
│  Multiplexer: Zellij                                    │
│  Editor: Neovim                                         │
└─────────────────────────────────────────────────────────┘
```

**Tooling philosophy:**
- `apt` for system-level packages that don't change often
- `mise` for portable runtimes and CLI tools across projects
- `pixi` for reproducible, per-project AI/ML environments with CUDA

---

## Setup

> Follow the steps **in order** — each layer depends on the one above it.

### Step 0: WSL

``` bash
wsl --update  # update WSL version
wsl --install Ubuntu-26.04
```

### Step 1: APT

```bash
sudo apt update && sudo apt upgrade -y
grep -v '^#' apt-packages.txt | xargs -r sudo apt install -y
```

Packages in [`apt-packages.txt`](./apt-packages.txt)

#### Git configuration

```bash
git config --global user.name  "<name>"
git config --global user.email "<email>"
git config --global core.editor "nvim"
# SSH key for GitHub
ssh-keygen -t ed25519 -C "<email>"
cat ~/.ssh/id_ed25519.pub # copy to SSH Github setting
```

### Step 2: Zsh

```bash
chsh -s $(which zsh)  # set Zsh as default shell
```

#### Zinit

[Zinit](https://github.com/zdharma-continuum/zinit) is a fast Zsh plugin manager with lazy-loading support.

```bash
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
```

Configuration for zsh is [here](./zsh)

### Step 3: mise

[mise](https://mise.jdx.dev) manages dev runtimes and CLI tools as versioned.

```bash
curl https://mise.run | sh
```

Configuration for mise is [here](./mise-en-place/config.toml)

Install runtimes and tools from the shared config:

```bash
mise install
```

*My configuration of CLI tools:* [Zellij](./zellij/config.kdl) · [Neovim](https://github.com/geminitt/neovim)

### Step 4: Pixi

[pixi](https://pixi.sh) creates conda-based, per-project environments. Ideal for locking CUDA versions alongside Python packages.

```bash
curl -fsSL https://pixi.sh/install.sh | bash
```

---

## Toolchain Summary

| Tool | Role | Managed by |
|---|---|---|
| `apt` | System libs, build tools | system |
| `mise` | Runtimes, CLI tools | system |
| `pixi` | Per-project AI/ML envs | system |
| `zsh` `zinit` | Shell + plugins | zsh file |
| `starship` | Prompt | mise (global) |
| `zellij` | Terminal multiplexer | mise (global) |
| `neovim` | Editor | mise (global) |
