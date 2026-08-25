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

---

## Architecture

> **NOTE:** Wezterm will not be used in this architecture because Windows Terminal is better suited to the Windows OS.

```
┌─────────────────────────────────────────────────────────┐
│  Windows Host                                           │
│  NVIDIA Driver (CUDA passthrough)                       │
└─────────────────────────┬───────────────────────────────┘
                          │ WSL2
┌─────────────────────────▼───────────────────────────────┐
│  1. APT — system layer                                  │
│     Build tools · system libs · git · curl              │
│     Docker engine (official)                            │
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

### Step 0

``` bash
wsl --update  # update WSL version
wsl --install Ubuntu-26.04
```

#### `.wslconfig` (Windows side)

Copy [`.wslconfig`](./.wslconfig) to `%UserProfile%\.wslconfig`, then **adjust `memory` / `processors` / `swap` to match your actual host resources** — the checked-in values are tuned for the original machine, not a sane default for every host.

```powershell
copy .wslconfig $env:USERPROFILE\.wslconfig
wsl --shutdown  # reload the new limits
```

### Step 1

#### Docker engine (must be added before installing `docker-ce`)

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### Install all packages

Packages in [`apt-packages.txt`](./apt-packages.txt)

```bash
sudo apt update && sudo apt upgrade -y
grep -v '^#' apt-packages.txt | xargs -r sudo apt install -y
```

#### Clone this repository

```bash
git clone https://github.com/geminitt/wsl.git ~/wsl
```

#### Docker daemon

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker $USER   # apply via `newgrp docker` or reopen WSL
```

#### Git configuration

```bash
git config --global user.name  "<name>"
git config --global user.email "<email>"
git config --global core.editor "nvim"
# SSH key for GitHub
ssh-keygen -t ed25519 -C "<email>"
cat ~/.ssh/id_ed25519.pub # copy to SSH Github setting
```

### Step 2

```bash
chsh -s $(which zsh)  # set Zsh as default shell
```

#### Zinit

[Zinit](https://github.com/zdharma-continuum/zinit) is a fast Zsh plugin manager with lazy-loading support.

```bash
bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
```

#### Symlink configuration

Links the tracked configs into `$HOME` (backs up any existing file with a `.bak` suffix first):

```bash
~/wsl/install.sh
```

Configuration for zsh is [here](./zsh)

### Step 3

[mise](https://mise.jdx.dev) manages dev runtimes and CLI tools as versioned.

```bash
curl https://mise.run | sh
```

Configuration for mise is [here](./mise-en-place/config.toml) — already symlinked to `~/.config/mise/config.toml` by `install.sh` (Step 2)

Install runtimes and tools from the shared config:

```bash
mise install
```

*My configuration of CLI tools:* [Zellij](./zellij/config.kdl) (also symlinked by `install.sh`) · [Neovim](https://github.com/geminitt/neovim)

### Step 4

[pixi](https://pixi.sh) creates conda-based, per-project environments. Ideal for locking CUDA versions alongside Python packages.

```bash
curl -fsSL https://pixi.sh/install.sh | bash
```
