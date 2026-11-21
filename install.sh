#!/usr/bin/env bash
# Interactive Ubuntu WSL setup. No Windows-side changes; safe to re-run.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APT_LIST="$REPO_DIR/packages-manager/apt/list-packages.txt"
MISE_CONFIG="$REPO_DIR/packages-manager/mise/config.toml"
PIXI_MANIFESTS="$REPO_DIR/packages-manager/pixi"
TEMP_DIR=''
DOCKER_READY=false
INSTALL_MODE=''
USER_NAME="$(id -un)"
declare -A STATUS=()

info() { printf '[WSL] %s\n' "$*"; }
warn() { printf '[WSL] WARNING: %s\n' "$*" >&2; }
fail() { printf '[WSL] ERROR: %s\n' "$*" >&2; exit 1; }
section() { printf '\n========== %s ==========\n' "$*"; }
mark() { STATUS["$1"]="$2"; info "$1: $2"; }

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}
on_error() {
  local status="$1" line="$2"
  warn "Stopped near line $line (exit status $status). Correct the problem and run ./install.sh again."
}
trap cleanup EXIT
trap 'on_error "$?" "$LINENO"' ERR

# Ask using the terminal, not standard input (which a caller may redirect).
ask() {
  local question="$1" default="$2" label answer
  [[ "$default" == y || "$default" == n ]] || fail "Invalid prompt default: $default"
  if [[ "$default" == y ]]; then label='Y/n'; else label='y/N'; fi
  while true; do
    printf '\n? %s [%s] ' "$question" "$label" > /dev/tty || fail 'Cannot write to the terminal.'
    IFS= read -r answer < /dev/tty || fail 'Cannot read from the terminal.'
    answer="${answer:-$default}"
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf '  Please answer y or n.\n' > /dev/tty ;;
    esac
  done
}

choose_mode() {
  local answer
  while true; do
    printf '\nWSL Environment Installer\n  1) Full installation\n  2) Symlinks only (no sudo, no downloads)\n  3) Exit\n' > /dev/tty
    printf 'Select [1/2/3] (default: 1): ' > /dev/tty
    IFS= read -r answer < /dev/tty || fail 'Cannot read installation mode.'
    case "${answer:-1}" in
      1) INSTALL_MODE=full; return 0 ;;
      2) INSTALL_MODE=links; return 0 ;;
      3) info 'Cancelled.'; exit 0 ;;
      *) printf '  Choose 1, 2 or 3.\n' > /dev/tty ;;
    esac
  done
}

preflight() {
  [[ $# -eq 0 ]] || fail 'Run ./install.sh without arguments; make selections interactively.'
  [[ -t 0 && -t 1 && -r /dev/tty ]] || fail 'Run the installer in an interactive terminal.'
  (( EUID != 0 )) || fail 'Run as a normal WSL user, not with sudo.'
  local file
  for file in packages-manager/apt/list-packages.txt packages-manager/mise/config.toml \
    packages-manager/pixi/pixi-global.toml zsh/.zshrc zsh/.zshenv zellij/config.kdl; do
    [[ -f "$REPO_DIR/$file" ]] || fail "Missing repository file: $file"
  done
  choose_mode
  if [[ "$INSTALL_MODE" == full ]]; then
    [[ -f /etc/os-release ]] || fail 'Cannot identify the Linux distribution.'
    # shellcheck source=/dev/null
    . /etc/os-release
    [[ "${ID:-}" == ubuntu ]] || fail 'Full setup supports Ubuntu only.'
    if ! grep -qi 'wsl2' /proc/sys/kernel/osrelease 2>/dev/null; then
      fail 'Full setup requires Ubuntu on WSL2 (the kernel release must identify WSL2).'
    fi
    for file in sudo apt-get dpkg-query grep sed git; do
      command -v "$file" >/dev/null 2>&1 || fail "Missing required command: $file"
    done
    if ! ask 'Continue with full installation?' y; then
      info 'Cancelled.'; exit 0
    fi
    sudo -v
    TEMP_DIR="$(mktemp -d)"
    info "Detected ${PRETTY_NAME:-Ubuntu} on WSL2."
  else
    info 'Symlinks only: system packages, Docker, mise install, Pixi sync and shell changes are disabled.'
  fi
}

# Never report success on a failed filesystem operation. Functions are sometimes
# called in `if` contexts, where Bash ignores `set -e` for their bodies.
managed_link() {
  local source="$1" destination="$2" backup
  [[ -e "$source" ]] || fail "Missing symlink source: $source"
  mkdir -p -- "$(dirname -- "$destination")" || fail "Cannot create parent directory: $destination"
  if [[ -L "$destination" && "$(readlink -- "$destination")" == "$source" ]]; then
    info "Already linked: $destination"
    return 0
  fi
  backup=''
  if [[ -e "$destination" || -L "$destination" ]]; then
    if ! ask "Back up and replace $destination?" n; then
      warn "Preserving existing path: $destination"
      return 1
    fi
    backup="${destination}.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
    [[ ! -e "$backup" && ! -L "$backup" ]] || fail "Backup already exists: $backup"
    mv -T -- "$destination" "$backup" || fail "Cannot back up: $destination"
    info "Backed up $destination -> $backup"
  fi
  if ! ln -s -- "$source" "$destination"; then
    if [[ -n "$backup" ]]; then
      mv -T -- "$backup" "$destination" || warn "Restore manually from $backup"
    fi
    fail "Cannot link $destination -> $source"
  fi
  info "Linked $destination -> $source"
}

cleanup_old_repo_links() {
  # Only unlink broken symlinks that precisely match paths managed by an old repo layout.
  local destination expected
  while IFS='|' read -r destination expected; do
    [[ -L "$destination" && ! -e "$destination" ]] || continue
    if [[ "$(readlink -- "$destination")" == "$expected" ]]; then
      if ask "Remove obsolete broken symlink $destination?" y; then
        rm -- "$destination" || fail "Cannot remove obsolete symlink: $destination"
        info "Removed obsolete symlink: $destination"
      fi
    fi
  done <<LINKS
$HOME/.config/mise/config.toml|$REPO_DIR/mise-en-place/config.toml
$HOME/.pixi/manifests|$REPO_DIR/pixi
$HOME/.claude/CLAUDE.md|$REPO_DIR/claude/CLAUDE.md
$HOME/.claude/settings.json|$REPO_DIR/claude/settings.json
LINKS
}

apply_dotfiles() {
  local skipped=0
  cleanup_old_repo_links
  managed_link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc" || skipped=$((skipped+1))
  managed_link "$REPO_DIR/zsh/.zshenv" "$HOME/.zshenv" || skipped=$((skipped+1))
  managed_link "$REPO_DIR/zellij/config.kdl" "$HOME/.config/zellij/config.kdl" || skipped=$((skipped+1))
  if (( skipped > 0 )); then mark 'Zsh/Zellij configuration' SKIPPED; else mark 'Zsh/Zellij configuration' SUCCESS; fi
}

apply_tool_manifests() {
  local skipped=0
  managed_link "$MISE_CONFIG" "$HOME/.config/mise/config.toml" || skipped=$((skipped+1))
  managed_link "$PIXI_MANIFESTS" "$HOME/.pixi/manifests" || skipped=$((skipped+1))
  if (( skipped > 0 )); then mark 'Tool manifests' SKIPPED; else mark 'Tool manifests' SUCCESS; fi
}

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
      docker-ce|docker-ce-cli|containerd.io|docker-buildx-plugin|docker-compose-plugin) DOCKER_PACKAGES+=("$package") ;;
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
  sudo apt-get install -y ca-certificates curl gnupg
  if ((${#BASE_PACKAGES[@]})); then sudo apt-get install -y "${BASE_PACKAGES[@]}"; fi
  mark APT SUCCESS
}

systemd_running() { [[ "$(ps -p 1 -o comm= | tr -d '[:space:]')" == systemd ]]; }
installed_package() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q 'install ok installed'; }
docker_running() { command -v docker >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; }

setup_docker_repo() {
  sudo install -m 0755 -d /etc/apt/keyrings
  if [[ ! -s /etc/apt/keyrings/docker.asc ]]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$TEMP_DIR/docker.asc" || fail 'Cannot download Docker key.'
    sudo install -m 0644 "$TEMP_DIR/docker.asc" /etc/apt/keyrings/docker.asc || fail 'Cannot install Docker key.'
  fi
  if [[ ! -f /etc/apt/sources.list.d/docker.sources && ! -f /etc/apt/sources.list.d/docker.list ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    local codename arch
    codename="${UBUNTU_CODENAME:-$VERSION_CODENAME}"
    arch="$(dpkg --print-architecture)"
    printf 'Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n' "$codename" "$arch" |
      sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null || fail 'Cannot configure Docker APT source.'
  fi
}

configure_docker_access() {
  if docker info >/dev/null 2>&1; then
    info 'Docker CLI works without sudo; LazyDocker can use the current Docker daemon.'
    return 0
  fi
  warn 'Docker daemon is running, but this user cannot yet access it without sudo (LazyDocker may fail).'
  if ! id -nG "$USER_NAME" | grep -qw docker; then
    if ask "Add $USER_NAME to the docker group? (Grants root-equivalent access)" n; then
      sudo usermod -aG docker "$USER_NAME" || fail 'Cannot add user to docker group.'
      warn 'Open a new WSL login for the docker group membership to become active.'
    fi
  else
    warn 'Docker group membership may require a new WSL login; reopen WSL and retry docker info.'
  fi
}

install_docker() {
  section '2/6  Docker Engine'
  if docker_running; then
    DOCKER_READY=true
    info 'Existing Docker Engine is running; no update or restart needed.'
    mark Docker SUCCESS
    configure_docker_access
    if ! ask 'Update the existing Docker Engine packages? (May interrupt running containers)' n; then
      info 'Keeping current Docker Engine packages.'
      return 0
    fi
  else
    DOCKER_READY=false
    if ! ask 'Install or repair Docker Engine inside Ubuntu WSL?' n; then
      mark Docker SKIPPED
      return 0
    fi
  fi
  if ! systemd_running; then
    warn 'systemd is not active. Enable it in /etc/wsl.conf and restart WSL before installing Docker Engine.'
    mark Docker BLOCKED
    return 0
  fi
  local package
  for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
    if installed_package "$package"; then
      warn "Conflicting Docker package installed: $package. Resolve this manually; no automatic removal."
      mark Docker BLOCKED
      return 0
    fi
  done
  setup_docker_repo
  sudo apt-get update
  ((${#DOCKER_PACKAGES[@]})) || fail 'Docker package list is empty.'
  sudo apt-get install -y "${DOCKER_PACKAGES[@]}"
  sudo systemctl enable --now docker
  if docker_running; then
    DOCKER_READY=true
    mark Docker SUCCESS
    configure_docker_access
  else
    DOCKER_READY=false
    mark Docker BLOCKED
    warn 'Docker packages were installed, but the daemon is not responding.'
  fi
}

nvidia_gpu_present() {
  local smi
  smi="$(command -v nvidia-smi || true)"
  [[ -n "$smi" ]] || smi=/usr/lib/wsl/lib/nvidia-smi
  [[ -x "$smi" ]] && "$smi" -L >/dev/null 2>&1
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
    warn 'No functional NVIDIA GPU detected within WSL; GPU setup skipped.'
    mark NVIDIA SKIPPED
    return 0
  fi
  if ((${#NVTOP_PACKAGES[@]})) && ask 'Install/update nvtop GPU monitor?' n; then
    sudo apt-get install -y "${NVTOP_PACKAGES[@]}"
  fi
  if [[ "$DOCKER_READY" != true ]]; then
    info 'NVIDIA Docker runtime skipped: the Docker daemon is not ready.'
    mark NVIDIA SKIPPED
    return 0
  fi
  if ! ask 'Configure NVIDIA GPU support for Docker containers?' n; then
    mark NVIDIA SKIPPED
    return 0
  fi
  if [[ -e /etc/docker/daemon.json && ! -f /etc/docker/daemon.json ]]; then
    warn '/etc/docker/daemon.json is not a regular file; refusing to modify.'
    mark NVIDIA BLOCKED
    return 0
  fi
  if [[ -f /etc/docker/daemon.json ]] && ! ask 'Back up and modify existing /etc/docker/daemon.json?' n; then
    mark NVIDIA SKIPPED
    return 0
  fi
  setup_nvidia_repo
  sudo apt-get update
  ((${#NVIDIA_PACKAGES[@]})) || fail 'NVIDIA packages not listed in APT manifest.'
  sudo apt-get install -y "${NVIDIA_PACKAGES[@]}"
  local old_hash='' new_hash='' backup=''
  if [[ -f /etc/docker/daemon.json ]]; then
    old_hash="$(sudo sha256sum /etc/docker/daemon.json | cut -d' ' -f1)"
    backup="/etc/docker/daemon.json.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
    sudo cp -a -- /etc/docker/daemon.json "$backup" || fail 'Cannot back up daemon.json.'
    info "Docker config backup: $backup"
  fi
  sudo nvidia-ctk runtime configure --runtime=docker
  [[ -f /etc/docker/daemon.json ]] || fail 'NVIDIA runtime configuration did not create daemon.json.'
  new_hash="$(sudo sha256sum /etc/docker/daemon.json | cut -d' ' -f1)"
  if [[ "$old_hash" == "$new_hash" ]]; then
    info 'NVIDIA runtime config unchanged; Docker restart is unnecessary.'
    mark NVIDIA SUCCESS
    return 0
  fi
  local count
  count="$(sudo docker ps -q | wc -l | tr -d '[:space:]')"
  warn "Docker runtime configuration changed; running containers: $count."
  if ask 'Restart Docker daemon now to apply NVIDIA runtime? (May interrupt containers)' n; then
    sudo systemctl restart docker
    if docker_running; then
      mark NVIDIA SUCCESS
    else
      mark NVIDIA BLOCKED
      warn 'Docker daemon failed to respond after restart.'
    fi
  else
    mark NVIDIA PENDING
    warn 'NVIDIA runtime is configured on disk but Docker must be restarted before it takes effect.'
  fi
}

install_mise() {
  section '4/6  mise / developer tools'
  if ! command -v mise >/dev/null 2>&1 && [[ ! -x "$HOME/.local/bin/mise" ]]; then
    curl -fsSL https://mise.run -o "$TEMP_DIR/mise-install.sh"
    sh "$TEMP_DIR/mise-install.sh"
  fi
  local mise_bin
  mise_bin="$(command -v mise || true)"
  [[ -n "$mise_bin" ]] || mise_bin="$HOME/.local/bin/mise"
  [[ -x "$mise_bin" ]] || fail 'mise executable not available.'
  if managed_link "$MISE_CONFIG" "$HOME/.config/mise/config.toml"; then
    "$mise_bin" install
    mark mise SUCCESS
  else
    warn 'Keeping existing mise config; repo-managed tool installation was skipped.'
    mark mise SKIPPED
  fi
}

install_pixi() {
  section '5/6  Pixi / global environments'
  if ! command -v pixi >/dev/null 2>&1 && [[ ! -x "$HOME/.pixi/bin/pixi" ]]; then
    curl -fsSL https://pixi.sh/install.sh -o "$TEMP_DIR/pixi-install.sh"
    PIXI_NO_PATH_UPDATE=1 bash "$TEMP_DIR/pixi-install.sh"
  fi
  local pixi_bin default
  pixi_bin="$(command -v pixi || true)"
  [[ -n "$pixi_bin" ]] || pixi_bin="$HOME/.pixi/bin/pixi"
  [[ -x "$pixi_bin" ]] || fail 'Pixi executable not available.'
  default=n
  [[ ! -d "$HOME/.pixi/envs" ]] && default=y
  if ! ask 'Use tracked Pixi global manifest and sync environments? (May REMOVE unlisted environments)' "$default"; then
    mark Pixi SKIPPED
    return 0
  fi
  if managed_link "$PIXI_MANIFESTS" "$HOME/.pixi/manifests"; then
    "$pixi_bin" global sync
    mark Pixi SUCCESS
  else
    warn 'Keeping existing Pixi manifest; no global sync performed.'
    mark Pixi SKIPPED
  fi
}

install_zinit() {
  local directory="$HOME/.local/share/zinit/zinit.git" backup
  if [[ -f "$directory/zinit.zsh" ]]; then return 0; fi
  if [[ -e "$directory" || -L "$directory" ]]; then
    warn "Zinit installation incomplete: $directory"
    if ! ask 'Back up incomplete Zinit directory and reinstall?' n; then
      return 1
    fi
    backup="${directory}.bak.$(date -u +%Y%m%dT%H%M%SZ).$$"
    mv -T -- "$directory" "$backup" || fail "Cannot back up incomplete Zinit directory: $directory"
  fi
  mkdir -p -- "$(dirname -- "$directory")" || fail 'Cannot create Zinit parent directory.'
  git clone --depth=1 https://github.com/zdharma-continuum/zinit.git "$directory"
  [[ -f "$directory/zinit.zsh" ]] || fail 'Zinit clone finished without zinit.zsh.'
}

setup_shell() {
  section '6/6  Zsh / dotfiles'
  local zinit_status=SUCCESS
  install_zinit || zinit_status=SKIPPED
  apply_dotfiles
  local zsh_bin current_shell
  zsh_bin="$(command -v zsh || true)"
  [[ -n "$zsh_bin" ]] || fail 'Zsh executable missing after APT install.'
  current_shell="$(getent passwd "$USER_NAME" | cut -d: -f7)"
  if [[ "$current_shell" != "$zsh_bin" ]]; then
    if ask 'Make Zsh the default login shell?' n; then
      sudo usermod --shell "$zsh_bin" "$USER_NAME"
      warn 'Reopen WSL to activate the new shell.'
    fi
  fi
  zsh -n "$REPO_DIR/zsh/.zshrc"
  zsh -n "$REPO_DIR/zsh/.zshenv"
  mark Zinit "$zinit_status"
}

verify() {
  section 'Verification summary'
  local item blocked=0
  for item in APT Docker NVIDIA mise Pixi Zinit 'Zsh/Zellij configuration'; do
    info "$item: ${STATUS[$item]:-NOT_RUN}"
    case "${STATUS[$item]:-NOT_RUN}" in
      BLOCKED|FAILED) blocked=1 ;;
    esac
  done
  if [[ "${STATUS[Docker]:-}" == SUCCESS ]]; then
    if ! docker_running; then warn 'Docker was marked successful, but the daemon is no longer responding.'; blocked=1; else
    info 'Docker daemon: ready'
    if docker info >/dev/null 2>&1; then
      info 'Docker CLI without sudo (LazyDocker): ready'
    else
      warn 'Docker requires sudo for current user; restart WSL after joining docker group, or review Docker access.'
    fi
    fi
  fi
  if [[ "${STATUS[mise]:-}" == SUCCESS ]]; then
    [[ -e "$HOME/.config/mise/config.toml" ]] || { warn 'mise config missing'; blocked=1; }
  fi
  if [[ "${STATUS[Pixi]:-}" == SUCCESS ]]; then
    [[ -e "$HOME/.pixi/manifests/pixi-global.toml" ]] || { warn 'Pixi manifest missing'; blocked=1; }
  fi
  if (( blocked )); then
    warn 'Setup contains BLOCKED/FAILED components; see above.'
    return 1
  fi
  info 'Setup complete. Check SKIPPED/PENDING components before use.'
  info 'Post-install: gh auth login; claude; hf auth login. Reopen WSL for shell/docker-group changes.'
}

main() {
  export PATH="$HOME/.local/bin:$HOME/.pixi/bin:$PATH"
  preflight "$@"
  if [[ "$INSTALL_MODE" == links ]]; then
    section 'Symlinks only'
    apply_dotfiles
    apply_tool_manifests
    info 'Symlinks-only setup complete (no package operations, sudo or service changes).'
    return 0
  fi
  cleanup_old_repo_links
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
