#!/usr/bin/env bash
# Interactive Ubuntu WSL setup. Windows-side settings are intentionally excluded.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APT_LIST="$REPO_DIR/packages-manager/apt/list-packages.txt"
MISE_CONFIG="$REPO_DIR/packages-manager/mise/config.toml"
PIXI_MANIFESTS="$REPO_DIR/packages-manager/pixi"
TEMP_DIR=''
DOCKER_READY=false

info() { printf '[WSL] %s\n' "$*"; }
warn() { printf '[WSL] WARNING: %s\n' "$*" >&2; }
fail() { printf '[WSL] ERROR: %s\n' "$*" >&2; exit 1; }
section() { printf '\n========== %s ==========\n' "$*"; }

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}
on_error() {
  local status="$1" line="$2"
  warn "Stopped near line $line (exit status $status). Fix the issue and run ./install.sh again."
}
trap cleanup EXIT
trap 'on_error "$?" "$LINENO"' ERR

# Always read from the controlling terminal, even if the installer is redirected.
ask() {
  local question="$1" default="$2" label answer
  [[ "$default" == 'y' || "$default" == 'n' ]] || fail "Invalid prompt default: $default"
  if [[ "$default" == 'y' ]]; then label='Y/n'; else label='y/N'; fi
  while true; do
    printf '\n? %s [%s] ' "$question" "$label" > /dev/tty || fail 'Cannot access the terminal.'
    IFS= read -r answer < /dev/tty || fail 'Cannot read an answer from the terminal.'
    answer="${answer:-$default}"
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf '  Enter y or n.\n' > /dev/tty ;;
    esac
  done
}

preflight() {
  section 'Environment checks'
  [[ $# -eq 0 ]] || fail 'Run ./install.sh without arguments; options are selected interactively.'
  [[ -t 0 && -t 1 && -r /dev/tty ]] || fail 'Run this installer in an interactive WSL terminal.'
  (( EUID != 0 )) || fail 'Run as a normal WSL user, not with sudo.'
  [[ -f /etc/os-release ]] || fail 'Cannot identify the Linux distribution.'
  # shellcheck source=/dev/null
  . /etc/os-release
  [[ "${ID:-}" == ubuntu ]] || fail 'This installer supports Ubuntu only.'
  if [[ -z "${WSL_DISTRO_NAME:-}" ]] && ! grep -qiE 'microsoft|wsl' /proc/sys/kernel/osrelease 2>/dev/null; then
    fail 'This installer is intended for Ubuntu running under WSL2.'
  fi
  local relative
  for relative in \
    packages-manager/apt/list-packages.txt \
    packages-manager/mise/config.toml \
    packages-manager/pixi/pixi-global.toml \
    zsh/.zshrc zsh/.zshenv zellij/config.kdl; do
    [[ -f "$REPO_DIR/$relative" ]] || fail "Missing repository file: $relative"
  done
  for cmd in sudo apt-get dpkg-query grep sed git; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Required system command missing: $cmd"
  done
  info "Detected ${PRETTY_NAME:-Ubuntu} on WSL."
  info 'Windows settings, SSH keys, credentials, and unrelated user files will not be modified.'
  if ! ask 'Continue with WSL environment setup?' y; then
    info 'Cancelled.'
    exit 0
  fi
  sudo -v
  TEMP_DIR="$(mktemp -d)"
}

# Compare the symlink itself; do not follow a broken target.
managed_link() {
  local source="$1" destination="$2" backup
  [[ -e "$source" ]] || fail "Missing link source: $source"
  mkdir -p -- "$(dirname -- "$destination")"
  if [[ -L "$destination" && "$(readlink -- "$destination")" == "$source" ]]; then
    info "Already linked: $destination"
    return 0
  fi
  if [[ -e "$destination" || -L "$destination" ]]; then
    if ! ask "Back up and replace $destination?" n; then
      warn "Preserving existing file: $destination"
      return 1
    fi
    backup="${destination}.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
    [[ ! -e "$backup" && ! -L "$backup" ]] || fail "Backup already exists: $backup"
    mv -T -- "$destination" "$backup"
    info "Backup created: $backup"
  fi
  ln -s -- "$source" "$destination"
  info "Linked $destination -> $source"
}

cleanup_old_claude_links() {
  # The old repo tracked claude/ settings. Only unlink precisely matching broken links.
  local file target
  for file in "$HOME/.claude/CLAUDE.md" "$HOME/.claude/settings.json"; do
    [[ -L "$file" ]] || continue
    target="$(readlink -- "$file")"
    if [[ "$target" == "$REPO_DIR/claude/${file##*/}" && ! -e "$file" ]]; then
      if ask "Remove obsolete broken symlink $file?" y; then
        rm -- "$file"
        info "Removed obsolete symlink: $file"
      fi
    fi
  done
}

# Read explicitly declared system packages. Docker and GPU tools are opt-in.
load_packages() {
  BASE_PACKAGES=()
  DOCKER_PACKAGES=()
  NVIDIA_PACKAGES=()
  NVTOP_PACKAGES=()
  local package
  while IFS= read -r package || [[ -n "$package" ]]; do
    package="${package%%#*}"
    package="${package//$'\r'/}"
    package="${package//[[:space:]]/}"
    [[ -n "$package" ]] || continue
    [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*$ ]] || fail "Invalid APT package: $package"
    case "$package" in
      docker-ce|docker-ce-cli|containerd.io|docker-buildx-plugin|docker-compose-plugin)
        DOCKER_PACKAGES+=("$package") ;;
      nvidia-container-toolkit) NVIDIA_PACKAGES+=("$package") ;;
      nvtop) NVTOP_PACKAGES+=("$package") ;;
      *) BASE_PACKAGES+=("$package") ;;
    esac
  done < "$APT_LIST"
}

install_system() {
  section '1/6  Ubuntu / APT'
  load_packages
  sudo apt-get update
  # Curl is needed for vendor repositories and official CLI installers; fresh WSL images may lack it.
  sudo apt-get install -y ca-certificates curl gnupg
  if ((${#BASE_PACKAGES[@]})); then
    sudo apt-get install -y "${BASE_PACKAGES[@]}"
  fi
}

systemd_running() {
  [[ "$(ps -p 1 -o comm= | tr -d '[:space:]')" == systemd ]]
}

setup_docker_repo() {
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -s /etc/apt/keyrings/docker.asc ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$TEMP_DIR/docker.asc"
    sudo install -m 0644 "$TEMP_DIR/docker.asc" /etc/apt/keyrings/docker.asc
  fi
  if [[ ! -f /etc/apt/sources.list.d/docker.sources && ! -f /etc/apt/sources.list.d/docker.list ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    local codename arch
    codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    arch="$(dpkg --print-architecture)"
    printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$codename" "$arch" |
      sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
  fi
}

installed_package() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'
}

install_docker() {
  section '2/6  Docker Engine'
  if ! ask 'Install or update Docker Engine inside Ubuntu WSL?' y; then
    info 'Docker installation skipped.'
    return 0
  fi
  local package
  for package in docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc; do
    if installed_package "$package"; then
      warn "Conflicting existing package: $package"
      warn 'Remove or migrate conflicting Docker packages manually; nothing will be removed automatically.'
      return 0
    fi
  done
  setup_docker_repo
  sudo apt-get update
  if ((${#DOCKER_PACKAGES[@]})); then
    sudo apt-get install -y "${DOCKER_PACKAGES[@]}"
  else
    fail 'Docker package list is empty in the repository manifest.'
  fi
  if systemd_running; then
    sudo systemctl enable --now docker
    DOCKER_READY=true
  else
    warn 'Docker packages installed, but systemd is not running. Enable systemd in /etc/wsl.conf and restart WSL.'
    return 0
  fi
  if ! id -nG "$USER" | grep -qw docker; then
    if ask "Add $USER to the docker group? (Grants root-equivalent access)" n; then
      sudo usermod -aG docker "$USER"
      warn 'The new group membership will take effect after a new WSL login.'
    fi
  fi
}

nvidia_gpu_present() {
  command -v nvidia-smi >/dev/null 2>&1 || [[ -x /usr/lib/wsl/lib/nvidia-smi ]]
}

setup_nvidia_repo() {
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -s /etc/apt/keyrings/nvidia-container-toolkit.gpg ]]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey -o "$TEMP_DIR/nvidia-key.asc"
    gpg --batch --yes --dearmor -o "$TEMP_DIR/nvidia-key.gpg" "$TEMP_DIR/nvidia-key.asc"
    sudo install -m 0644 "$TEMP_DIR/nvidia-key.gpg" /etc/apt/keyrings/nvidia-container-toolkit.gpg
  fi
  if [[ ! -f /etc/apt/sources.list.d/nvidia-container-toolkit.list ]]; then
    curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list -o "$TEMP_DIR/nvidia.list"
    sed 's#deb https://#deb [signed-by=/etc/apt/keyrings/nvidia-container-toolkit.gpg] https://#g' \
      "$TEMP_DIR/nvidia.list" | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list >/dev/null
  fi
}

install_nvidia() {
  section '3/6  NVIDIA / GPU'
  if ! nvidia_gpu_present; then
    info 'No NVIDIA WSL GPU detected; skipping NVIDIA setup.'
    return 0
  fi
  if ((${#NVTOP_PACKAGES[@]})) && ask 'Install nvtop for GPU monitoring?' n; then
    sudo apt-get install -y "${NVTOP_PACKAGES[@]}"
  fi
  if [[ "$DOCKER_READY" != true ]]; then
    info 'NVIDIA Container Toolkit skipped because the in-WSL Docker daemon is not configured.'
    return 0
  fi
  if ! ask 'Enable NVIDIA GPU support for Docker containers?' n; then
    info 'NVIDIA Container Toolkit skipped.'
    return 0
  fi
  setup_nvidia_repo
  sudo apt-get update
  if ((${#NVIDIA_PACKAGES[@]})); then
    sudo apt-get install -y "${NVIDIA_PACKAGES[@]}"
  else
    fail 'NVIDIA toolkit package is missing from the APT manifest.'
  fi
  # nvidia-ctk updates daemon.json; preserve the original before any change.
  if [[ -f /etc/docker/daemon.json ]]; then
    if ! ask 'Back up and update existing /etc/docker/daemon.json?' n; then
      warn 'Skipped Docker NVIDIA runtime configuration; toolkit packages remain installed.'
      return 0
    fi
    local backup
    backup="/etc/docker/daemon.json.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
    sudo cp -a -- /etc/docker/daemon.json "$backup"
    info "Docker daemon config backed up: $backup"
  fi
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
  info 'GPU runtime configured. Verify later: sudo docker run --rm --gpus all ubuntu nvidia-smi'
}

install_mise() {
  section '4/6  mise / developer tooling'
  if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    info 'Installing mise from the official installer.'
    curl -fsSL https://mise.run -o "$TEMP_DIR/mise-install.sh"
    sh "$TEMP_DIR/mise-install.sh"
  fi
  local mise_bin
  mise_bin="$(command -v mise || true)"
  [[ -n "$mise_bin" ]] || mise_bin="$HOME/.local/bin/mise"
  [[ -x "$mise_bin" ]] || fail 'mise is not installed or executable.'
  if managed_link "$MISE_CONFIG" "$HOME/.config/mise/config.toml"; then
    "$mise_bin" install
  else
    warn 'Skipping mise tool installation because your existing global config was retained.'
  fi
}

install_pixi() {
  section '5/6  Pixi / shared environments'
  if ! command -v pixi >/dev/null 2>&1 && [[ ! -x "$HOME/.pixi/bin/pixi" ]]; then
    info 'Installing Pixi from the official installer.'
    curl -fsSL https://pixi.sh/install.sh -o "$TEMP_DIR/pixi-install.sh"
    PIXI_NO_PATH_UPDATE=1 bash "$TEMP_DIR/pixi-install.sh"
  fi
  local pixi_bin
  pixi_bin="$(command -v pixi || true)"
  [[ -n "$pixi_bin" ]] || pixi_bin="$HOME/.pixi/bin/pixi"
  [[ -x "$pixi_bin" ]] || fail 'Pixi is not installed or executable.'
  if managed_link "$PIXI_MANIFESTS" "$HOME/.pixi/manifests"; then
    local default='n'
    [[ -d "$HOME/.pixi/envs" ]] || default='y'
    if ask 'Sync Pixi global tools with this repository? (Unlisted environments may be removed)' "$default"; then
      "$pixi_bin" global sync
    else
      info 'Pixi global sync skipped.'
    fi
  else
    warn 'Pixi global sync skipped because the current manifest was retained.'
  fi
}

install_zinit() {
  local directory="$HOME/.local/share/zinit/zinit.git"
  if [[ -f "$directory/zinit.zsh" ]]; then return 0; fi
  if [[ -e "$directory" ]]; then
    warn "Zinit directory exists but is incomplete: $directory"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$directory")"
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$directory"
}

setup_shell() {
  section '6/6  Zsh / dotfiles'
  install_zinit
  cleanup_old_claude_links
  managed_link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc" || true
  managed_link "$REPO_DIR/zsh/.zshenv" "$HOME/.zshenv" || true
  managed_link "$REPO_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl" || true
  local zsh_bin current_shell
  zsh_bin="$(command -v zsh || true)"
  [[ -n "$zsh_bin" ]] || fail 'Zsh was not installed by APT.'
  current_shell="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current_shell" != "$zsh_bin" ]]; then
    if ask 'Set Zsh as the default login shell?' n; then
      sudo usermod --shell "$zsh_bin" "$USER"
      warn 'Reopen WSL to activate the new login shell.'
    fi
  fi
  zsh -n "$REPO_DIR/zsh/.zshrc"
  zsh -n "$REPO_DIR/zsh/.zshenv"
}

verify() {
  section 'Verification'
  local component missing=0
  for component in mise pixi zsh; do
    if command -v "$component" >/dev/null 2>&1; then
      info "$component: $(command -v "$component")"
    elif [[ -x "$HOME/.local/bin/$component" || -x "$HOME/.pixi/bin/$component" ]]; then
      info "$component: installed (available on PATH after opening a new shell)"
    else
      warn "$component is unavailable."
      missing=1
    fi
  done
  for component in "$HOME/.config/mise/config.toml" "$HOME/.pixi/manifests/pixi-global.toml"; do
    if [[ ! -e "$component" ]]; then
      warn "Expected config missing: $component"
      missing=1
    fi
  done
  if [[ "$DOCKER_READY" == true ]]; then
    if sudo docker info >/dev/null 2>&1; then
      info 'Docker daemon: ready'
    else
      warn 'Docker daemon is not responding.'
      missing=1
    fi
  fi
  if ((missing)); then
    warn 'Setup finished with warnings. See above and rerun after addressing the issues.'
  else
    info 'Setup completed; basic checks passed.'
  fi
  info 'Next: reopen WSL when needed, then authenticate with gh auth login, claude, and hf auth login.'
}

main() {
  export PATH="$HOME/.local/bin:$HOME/.pixi/bin:$PATH"
  preflight "$@"
  install_system
  install_docker
  install_nvidia
  install_mise
  install_pixi
  setup_shell
  verify
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
