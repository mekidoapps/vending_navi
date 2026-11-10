"""Capture console in memory; persist only closed-schema application events."""
import json
import os
from pathlib import Path
import signal
import subprocess
import threading
import time

EVENTS = {'appcheck', 'viewport_v2', 'viewport_legacy', 'machine_detail', 'viewport_state'}
RESULTS = {'started', 'accepted', 'ready', 'empty', 'loading', 'permission-denied',
           'failed-precondition', 'unavailable', 'deadline-exceeded', 'resource-exhausted',
           'unauthenticated', 'invalid-configuration', 'server-unreachable', 'code-keychain',
           'code-unsupported', 'network', 'authentication', 'permission', 'validation',
           'rate-limit', 'not-found', 'unknown', 'other'}
MARKER = '[CAPTURE_DIAGNOSTIC] '


def parse_event(line):
    if len(line) > 512 or MARKER not in line:
        return None
    try:
        value = json.loads(line.split(MARKER, 1)[1])
        if (isinstance(value, dict) and set(value) == {'event', 'result'}
                and value['event'] in EVENTS and value['result'] in RESULTS):
            return value
    except (ValueError, TypeError):
        pass
    return None


class AppDiagnostics:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.records = []
        self.latest = {}
        self.lock = threading.Lock()
        self.process = None

    def accept(self, line):
        event = parse_event(line)
        if event is None:
            return
        with self.lock:
            self.records = (self.records + [event])[-100:]
            self.latest[event['event']] = event['result']
            try:
                self.directory.mkdir(mode=0o700, parents=True, exist_ok=True)
                temporary = self.directory / 'app.tmp'
                temporary.write_text(json.dumps({'events': self.records}))
                temporary.replace(self.directory / 'app.json')
            except Exception:
                pass  # Persistence failure must not leak raw console/error text.

    def healthy(self):
        with self.lock:
            return (self.latest.get('appcheck') == 'accepted'
                    and self.latest.get('viewport_state') in {'ready', 'empty'})

    def start(self, args, env):
        self.process = subprocess.Popen(args, env=env, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, start_new_session=True)
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        pending = b''
        oversized = False
        try:
            while True:
                chunk = self.process.stdout.read1(1024)
                if not chunk:
                    break
                for part in chunk.splitlines(keepends=True):
                    if not oversized:
                        pending += part
                        if len(pending) > 512:
                            pending = b''
                            oversized = True
                    if part.endswith(b'\n'):
                        if not oversized:
                            self.accept(pending.decode('utf-8', errors='replace').strip())
                        pending = b''
                        oversized = False
        except Exception:
            pass  # Never print exceptions or raw SDK output (may contain debug tokens).

    def wait_ready(self, seconds):
        end = time.monotonic() + seconds
        stable_since = None
        while time.monotonic() < end:
            if self.healthy():
                stable_since = stable_since or time.monotonic()
                if time.monotonic() - stable_since >= 2:
                    return True
            else:
                stable_since = None
            if self.process.poll() is not None:
                return False
            time.sleep(0.1)
        return False

    def stop(self):
        if self.process is None or self.process.poll() is not None:
            return True
        try:
            os.killpg(self.process.pid, signal.SIGTERM)
            self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(self.process.pid, signal.SIGKILL)
                self.process.wait(timeout=5)
            except (OSError, subprocess.TimeoutExpired):
                return False
        except OSError:
            return self.process.poll() is not None
        return True
