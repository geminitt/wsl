#!/usr/bin/env python3
"""Offline regression tests. Never install packages or change host services."""
import os
import pty
import select
import subprocess
import tempfile
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'install.sh'


def bash(snippet, home=None):
    env = os.environ.copy()
    if home is not None:
        env['HOME'] = str(home)
    return subprocess.run(
        ['bash', '-c', f'source "{SCRIPT}"; {snippet}'],
        env=env, text=True, capture_output=True, timeout=15,
    )


def terminal(command, replies, home=None, timeout=15):
    """Run an isolated interactive shell with controlling tty and scripted replies."""
    pid, fd = pty.fork()
    if pid == 0:
        if home is not None:
            os.environ['HOME'] = str(home)
        os.execv('/bin/bash', ['bash', '-c', command])
    transcript = b''
    sent = 0
    status = None
    started = time.monotonic()
    while time.monotonic() - started < timeout:
        ready, _, _ = select.select([fd], [], [], 0.08)
        if ready:
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:
                break
            transcript += chunk
            # One reply per prompt. Every line that is a prompt ends with a space.
            prompt_count = transcript.count(b' [Y/n] ') + transcript.count(b' [y/N] ')
            prompt_count += transcript.count(b'(default: 1): ')
            while sent < min(prompt_count, len(replies)):
                os.write(fd, (replies[sent] + '\n').encode())
                sent += 1
        finished, code = os.waitpid(pid, os.WNOHANG)
        if finished:
            status = os.waitstatus_to_exitcode(code)
            break
    if status is None:
        try:
            os.kill(pid, 9)
        except ProcessLookupError:
            pass
        _, code = os.waitpid(pid, 0)
        status = os.waitstatus_to_exitcode(code)
    os.close(fd)
    return status, transcript.decode(errors='replace')


class InstallerTests(unittest.TestCase):
    def test_shell_syntax(self):
        proc = subprocess.run(['bash', '-n', str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0, proc.stderr)

    def test_package_groups(self):
        r = bash('load_packages; echo "${#BASE_PACKAGES[@]} ${#DOCKER_PACKAGES[@]} ${#NVIDIA_PACKAGES[@]} ${#NVTOP_PACKAGES[@]}"')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('25 5 1 1', r.stdout)

    def test_new_link_and_idempotent(self):
        with tempfile.TemporaryDirectory() as t:
            snippet = 'managed_link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"; managed_link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"; test -L "$HOME/.zshrc"'
            r = bash(snippet, t)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('Already linked', r.stdout)

    def test_replace_creates_backup(self):
        with tempfile.TemporaryDirectory() as t:
            Path(t, '.zshrc').write_text('original')
            r = bash('ask() { return 0; }; managed_link "$REPO_DIR/zsh/.zshrc" "$HOME/.zshrc"', t)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(Path(t, '.zshrc').is_symlink())
            backups = list(Path(t).glob('.zshrc.bak.*'))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), 'original')

    def test_reject_keeps_original(self):
        with tempfile.TemporaryDirectory() as t:
            dest = Path(t, '.zshrc')
            dest.write_text('original')
            r = bash('ask() { return 1; }; managed_link "$REPO_DIR/zsh/.zshenv" "$HOME/.zshrc" || :', t)
            self.assertEqual(r.returncode, 0)
            self.assertEqual(dest.read_text(), 'original')

    def test_directory_backup(self):
        with tempfile.TemporaryDirectory() as t:
            dest = Path(t, '.pixi', 'manifests')
            dest.mkdir(parents=True)
            (dest / 'mine.toml').write_text('mine')
            r = bash('ask() { return 0; }; managed_link "$PIXI_MANIFESTS" "$HOME/.pixi/manifests"', t)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertTrue(dest.is_symlink())
            self.assertEqual(len(list(dest.parent.glob('manifests.bak.*/mine.toml'))), 1)

    def test_link_failure_not_false_success(self):
        r = bash('managed_link "$REPO_DIR/zsh/.zshrc" /dev/null/invalid')
        self.assertNotEqual(r.returncode, 0)
        self.assertNotIn('Linked /dev/null/invalid', r.stdout)
        self.assertIn('Cannot create parent directory', r.stderr)

    def test_migration_broken_mise_and_pixi(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            d = home / '.config' / 'mise'
            d.mkdir(parents=True)
            (home / '.pixi').mkdir()
            (d / 'config.toml').symlink_to(ROOT / 'mise-en-place' / 'config.toml')
            (home / '.pixi' / 'manifests').symlink_to(ROOT / 'pixi')
            r = bash('ask() { return 0; }; cleanup_old_repo_links; apply_tool_manifests', t)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual((d / 'config.toml').resolve(), ROOT / 'packages-manager' / 'mise' / 'config.toml')
            self.assertEqual((home / '.pixi' / 'manifests').resolve(), ROOT / 'packages-manager' / 'pixi')

    def test_unrelated_broken_symlink_preserved(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            d = home / '.config' / 'mise'
            d.mkdir(parents=True)
            (d / 'config.toml').symlink_to('/different/repo/obsolete')
            r = bash('ask() { return 0; }; cleanup_old_repo_links', t)
            self.assertEqual(r.returncode, 0)
            self.assertTrue((d / 'config.toml').is_symlink())

    def test_pixisync_declined_never_changes_manifest(self):
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            (home / '.pixi' / 'bin').mkdir(parents=True)
            binary = home / '.pixi' / 'bin' / 'pixi'
            binary.write_text('#!/bin/sh\nexit 0\n')
            binary.chmod(0o755)
            target = home / '.pixi' / 'manifests'
            target.mkdir()
            (target / 'mine.toml').write_text('keep')
            r = bash('ask() { return 1; }; install_pixi; test -f "$HOME/.pixi/manifests/mine.toml"', t)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('Pixi: SKIPPED', r.stdout)

    def test_docker_kept_when_already_running(self):
        code = '''
        sudo() { return 0; }
        docker() { return 0; }
        configure_docker_access() { :; }
        ask() { return 1; }
        install_docker
        [[ "$DOCKER_READY" == true && "${STATUS[Docker]}" == SUCCESS ]]
        '''
        r = bash(code)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('Keeping current Docker Engine packages.', r.stdout)

    def test_docker_declined(self):
        code = '''docker_running() { return 1; }; ask() { return 1; }; install_docker; [[ "${STATUS[Docker]}" == SKIPPED ]]'''
        r = bash(code)
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_docker_buildx_conflict(self):
        code = '''
        docker_running() { return 1; }
        systemd_running() { return 0; }
        ask() { return 0; }
        installed_package() { [[ "$1" == docker-buildx ]]; }
        install_docker
        [[ "${STATUS[Docker]}" == BLOCKED ]]
        '''
        r = bash(code)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn('docker-buildx', r.stderr)

    def test_existing_docker_allows_nvidia_question(self):
        code = '''
        docker_running() { return 0; }
        configure_docker_access() { :; }
        ask() { return 1; }
        install_docker
        nvidia_gpu_present() { return 0; }
        load_packages
        install_nvidia
        [[ "${STATUS[NVIDIA]}" == SKIPPED && "$DOCKER_READY" == true ]]
        '''
        r = bash(code)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn('daemon is not ready', r.stdout)

    def test_verify_blocked_nonzero(self):
        r = bash('STATUS[Docker]=BLOCKED; verify')
        self.assertNotEqual(r.returncode, 0)
        self.assertIn('BLOCKED', r.stdout+r.stderr)

    def test_mocked_full_install_flow(self):
        # Run the real main() without host sudo/apt/systemd/network side effects.
        with tempfile.TemporaryDirectory() as t:
            home = Path(t)
            fake = home / 'bin'
            fake.mkdir()
            for executable in ['mise', 'pixi', 'docker', 'zsh']:
                path = fake / executable
                path.write_text('#!/bin/sh\nexit 0\n')
                path.chmod(0o755)
            code = f'''
            export PATH="{fake}:$PATH"
            preflight() {{ INSTALL_MODE=full; TEMP_DIR="$(mktemp -d)"; }}
            sudo() {{ return 0; }}
            docker() {{ return 0; }}
            systemd_running() {{ return 0; }}
            nvidia_gpu_present() {{ return 1; }}
            install_zinit() {{ return 0; }}
            ask() {{ case "$1" in *'Pixi global manifest'*) return 0 ;; *) return 1 ;; esac; }}
            main
            echo "end=${{STATUS[APT]}}:${{STATUS[Docker]}}:${{STATUS[mise]}}:${{STATUS[Pixi]}}"
            '''
            r = bash(code, t)
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
            self.assertIn('end=SUCCESS:SUCCESS:SUCCESS:SUCCESS', r.stdout)
            self.assertTrue((home / '.pixi' / 'manifests').is_symlink())

    def test_mocked_apt_failure_stops_installation(self):
        with tempfile.TemporaryDirectory() as t:
            code = '''
            preflight() { INSTALL_MODE=full; TEMP_DIR="$(mktemp -d)"; }
            sudo() { if [[ "$*" == 'apt-get update' ]]; then return 100; fi; return 0; }
            main
            '''
            r = bash(code, t)
            self.assertEqual(r.returncode, 100, r.stdout + r.stderr)
            self.assertNotIn('mise / developer tools', r.stdout)

    def test_zsh_fzf_hook_present(self):
        s = (ROOT / 'zsh' / '.zshrc').read_text()
        self.assertIn('zvm_after_init_commands', s)
        self.assertIn('source <(fzf --zsh)', s)
        self.assertLess(s.index('zvm_after_init_commands'), s.index('jeffreytse/zsh-vi-mode'))

    def test_interactive_yes_no(self):
        for answer, expected in [('yes', 'YES'), ('no', 'NO'), ('', 'NO')]:
            cmd = f'source "{SCRIPT}"; if ask "Proceed?" n; then echo YES; else echo NO; fi'
            status, output = terminal(cmd, [answer])
            self.assertEqual(status, 0, output)
            self.assertIn(expected, output)

    def test_interactive_symlinks_only_no_sudo(self):
        # Real executable path, full preflight including mode choice, no mocks.
        with tempfile.TemporaryDirectory() as t:
            if os.geteuid() == 0:
                self.skipTest('interactive entrypoint must run as non-root')
            status, out = terminal(str(SCRIPT), ['2'], t)
            self.assertEqual(status, 0, out)
            self.assertIn('Symlinks-only setup complete', out)
            home = Path(t)
            for f in ['.zshrc', '.zshenv', '.config/zellij/config.kdl', '.config/mise/config.toml', '.pixi/manifests']:
                self.assertTrue((home / f).is_symlink(), f)
            # Repeated invocation should be a no-op.
            status, out = terminal(str(SCRIPT), ['2'], t)
            self.assertEqual(status, 0, out)
            self.assertGreaterEqual(out.count('Already linked:'), 5)


if __name__ == '__main__':
    unittest.main(verbosity=2)
