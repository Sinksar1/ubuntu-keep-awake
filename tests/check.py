#!/usr/bin/env python3
"""Safe backend smoke test: no privileged paths or real inhibition."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
metadata = json.loads((ROOT / 'gnome-extension/keepawake@fitz/metadata.json').read_text())
assert metadata['uuid'] == 'keepawake@fitz'
assert metadata['shell-version'] == ['46']

with tempfile.TemporaryDirectory(prefix='keep-awake-test-') as directory:
    temp = Path(directory)
    pidfile = temp / 'keep-awake.pid'
    backend = temp / 'keep-awake'
    source = (ROOT / 'bin/keep-awake').read_text()
    assert source.count('/run/keep-awake.pid') == 1
    backend.write_text(source.replace('/run/keep-awake.pid', str(pidfile)))
    mock = temp / 'systemd-inhibit'
    mock.write_text('#!/bin/bash\nprintf "%s\\n" "$@" > "$TEST_ARGS"\nexec /usr/bin/sleep 60 >/dev/null 2>&1\n')
    mock.chmod(0o755)
    env = dict(os.environ, PATH=f'{temp}:/usr/bin:/bin', TEST_ARGS=str(temp / 'args'))

    def run(action):
        return subprocess.run(['/bin/bash', str(backend), action], env=env,
                              capture_output=True, text=True, timeout=5)

    pid = None
    try:
        assert run('status').stdout.strip() == 'Keep Awake: OFF'
        assert run('invalid').returncode == 1
        assert run('on').stdout.strip() == 'Keep Awake: ON'
        pid = int(pidfile.read_text())
        assert run('status').stdout.strip() == 'Keep Awake: ON'
        assert run('on').stdout.strip() == 'Keep Awake is already ON'
        assert int(pidfile.read_text()) == pid
        for _ in range(100):
            if (temp / 'args').exists():
                break
            time.sleep(0.01)
        assert (temp / 'args').read_text().splitlines() == [
            '--what=handle-lid-switch:sleep', '--who=Keep Awake',
            '--why=Keep laptop running with lid closed for remote access',
            '--mode=block', 'sleep', 'infinity',
        ]
        assert run('off').stdout.strip() == 'Keep Awake: OFF'
        assert not pidfile.exists()
        assert run('status').stdout.strip() == 'Keep Awake: OFF'
        assert run('off').returncode == 0
    finally:
        if pid is not None:
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass
print('PASS: metadata, on/off/status, duplicate on, exact inhibitor arguments, invalid action')
