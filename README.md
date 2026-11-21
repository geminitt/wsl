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
| --- | --- |
| Windows 11 | WSL2 support required |
| WSL2 | Ubuntu 26.04 LTS |
| NVIDIA Windows driver | Optional; required only for NVIDIA GPU workloads in WSL |

---

## Architecture

> **Note:** Windows Terminal is the preferred terminal on Windows. The WezTerm configuration is retained for reference but is not part of the installation.

![WSL architecture](./docs/architecture.packages-manager.png)

**Tooling philosophy:**

- `apt` manages Ubuntu system packages, native libraries, build dependencies, and system-level services.
- `mise` manages developer tools, coding agents, and standalone runtimes used across projects.
- `pixi` manages isolated, reproducible project environments, including language runtimes, dependencies, and CUDA libraries when needed. `pixi global` manages shared CLI tools distributed through conda-forge, without `uv`.

**Principle:** Each tool has one primary package manager. Project dependencies belong to Pixi; shared development tools belong to mise; system-level dependencies belong to APT.

---

## Setup

### Windows side

Run in PowerShell:

```powershell
wsl --update
wsl --list --online                    # Check the distribution name
wsl --install -d Ubuntu-26.04         # Install the chosen distribution
```

**Optional — WSL resource limits:**

Download [`.wslconfig`](./.wslconfig) to a directory on Windows and adjust its `memory`, `processors`, and `swap` settings for your host. From that directory, run:

```powershell
Copy-Item .\.wslconfig "$env:USERPROFILE\.wslconfig"
wsl --shutdown                       # Stops all WSL distributions
```

The checked-in limits reflect the original machine and are not defaults for every host. The Windows-side NVIDIA driver, when needed, is installed on Windows, not inside Ubuntu WSL.

### WSL side

Open Ubuntu WSL and run:

```bash
sudo apt update && sudo apt install -y git
git clone https://github.com/geminitt/wsl.git ~/wsl
cd ~/wsl
./install.sh
```

The installer **asks questions interactively while configuring each step**; no command-line options are needed:

1. Install Ubuntu packages declared in [`list-packages.txt`](./packages-manager/apt/list-packages.txt).
2. Optionally install Docker Engine from Docker's official APT repository; ask separately about Docker group membership (root-equivalent access).
3. If an NVIDIA GPU is available in WSL, optionally install GPU monitoring and configure NVIDIA Container Toolkit for Docker.
4. Install mise and the shared tools in [`config.toml`](./packages-manager/mise/config.toml).
5. Install Pixi and ask before synchronizing [`pixi-global.toml`](./packages-manager/pixi/pixi-global.toml). Sync may remove global environments absent from the manifest.
6. Install Zinit, link Zsh/Zellij configuration files, and optionally make Zsh the default shell.

Existing conflicting dotfiles are preserved unless you approve their replacement; the original file is then saved with a timestamped `.bak.*` name. Re-running the script skips symlinks already pointing to the correct files. The installer does not remove conflicting Docker packages or manage Windows settings.

**Post-installation:** Reopen WSL if you changed the default shell or joined the Docker group. Authenticate services individually:

```bash
gh auth login
claude                   # Follow the interactive login instructions
hf auth login
```

For NVIDIA Docker support, verify after the runtime is configured:

```bash
sudo docker run --rm --gpus all ubuntu nvidia-smi
```

The installer checks basic configuration and command availability, but a complete fresh-WSL installation still requires end-to-end testing on the target system.
