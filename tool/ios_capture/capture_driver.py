"""LOCAL DRAFT. Hosted macOS only; no external access registration/deletion.
Place under tool/ios_capture only after separate review. Never print credentials.
"""
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import struct
import subprocess
import sys
import time
from contextlib import contextmanager

DIAGNOSTIC_ROOT = None
EVENTS = []
DEADLINE_START = None
ACTIVE_PHASE = 'preflight'
PHASE_LIMIT = {'preflight': 9 * 60, 'build': 31 * 60,
               'capture': 39 * 60, 'cleanup': 42 * 60}
OPERATIONS = {'start', 'boot', 'bootstatus', 'install', 'permission', 'location',
              'launch', 'wait', 'screenshot', 'dimensions', 'terminate', 'shutdown',
              'inventory', 'clear', 'settings', 'prepare'}


def safe_print(value):
    try:
        print(value, flush=True)
    except Exception:
        pass


def bounded_timeout(requested):
    if DEADLINE_START is None:
        return requested  # Local unit tests only; main requires the budget file.
    remaining = DEADLINE_START + PHASE_LIMIT[ACTIVE_PHASE] - time.monotonic()
    if remaining <= 1:
        raise subprocess.TimeoutExpired('phase_deadline', 0)
    return min(requested, remaining - 1)


def restore_diagnostics():
    try:
        saved = json.loads((DIAGNOSTIC_ROOT / 'stages.json').read_text())
        validated = []
        for e in saved['events']:
            need(set(e) <= {'target', 'stage', 'status', 'kind', 'exit_code', 'timeout_seconds', 'elapsed_seconds'})
            need(e.get('target') in {'capture', 'cleanup', 'ipad13', 'iphone-dynamic-medium'})
            need(e.get('stage') in OPERATIONS)
            need(e.get('status') in {'started', 'complete', 'failed'})
            need(e.get('kind', 'exit') in {'exit', 'timeout', 'check_or_interrupt'})
            for key in ('exit_code', 'timeout_seconds', 'elapsed_seconds'):
                need(key not in e or type(e[key]) in {int, float} and abs(e[key]) < 10000000)
            validated.append(e)
        EVENTS.extend(validated)
    except FileNotFoundError:
        pass
    except Exception:
        safe_print('diagnostics_restore_unavailable')


class CommandFailure(RuntimeError):
    def __init__(self, code):
        self.code = int(code)


@contextmanager
def stage(target, operation):
    # Closed vocabulary only: never serialize commands, exceptions, env or SDK output.
    need(target in {'capture', 'cleanup', 'ipad13', 'iphone-dynamic-medium'})
    need(operation in OPERATIONS)
    started = time.monotonic()
    event = {'target': target, 'stage': operation, 'status': 'started'}
    def save():
        try:
            if DIAGNOSTIC_ROOT is not None:
                DIAGNOSTIC_ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
                temporary = DIAGNOSTIC_ROOT / 'stages.tmp'
                temporary.write_text(json.dumps(
                    {'classification': 'DIAGNOSTIC_ONLY_NOT_STORE_APPROVED', 'events': EVENTS}, indent=2))
                temporary.replace(DIAGNOSTIC_ROOT / 'stages.json')
        except Exception:
            safe_print('diagnostics_save_unavailable')
    EVENTS.append(event)
    save()
    try:
        yield
        event['status'] = 'complete'
    except BaseException as error:
        event['status'] = 'failed'
        event['kind'] = ('timeout' if isinstance(error, subprocess.TimeoutExpired)
                         else 'exit' if isinstance(error, CommandFailure) else 'check_or_interrupt')
        if isinstance(error, CommandFailure):
            event['exit_code'] = error.code
        if isinstance(error, subprocess.TimeoutExpired):
            event['timeout_seconds'] = float(error.timeout)
        raise
    finally:
        event['elapsed_seconds'] = round(time.monotonic() - started, 3)
        save()
        safe_print(json.dumps(event))

SOURCE = 'b8abf91740eec97a260794b5e6923acd688502ed'
LOCK = '3d9233f72b9f70f73f4f6482bf50510049ad37d94cf24f80ccaf8859331a7b96'
BUNDLE = 'com.mekidoapps.vendingnavi'
APP_ID = '1:589528386744:ios:e6afb2ac27e7a1e552784d'
RUNTIME = 'com.apple.CoreSimulator.SimRuntime.iOS-26-2'
SERVICES = ('GOOGLE_MAPS_IOS_API_KEY', 'GOOGLE_SIGN_IN_IOS_CLIENT_ID', 'GOOGLE_SIGN_IN_REVERSED_CLIENT_ID')
TARGETS = [('ipad13', 'iPad Pro 13-inch (M4)', {(2064, 2752), (2048, 2732)}),
           ('iphone-dynamic-medium', 'iPhone 16', {(1179, 2556), (1206, 2622)})]


def need(condition):
    if not condition:
        raise RuntimeError('Capture prerequisite failed; inspect phase and BLOCKING.txt')


def command(args, *, cwd=None, env=None, timeout=120):
    timeout = bounded_timeout(timeout)
    # No stdout/stderr, token or SDK logs are forwarded to Actions logs/artifacts.
    p = subprocess.Popen(args, cwd=cwd, env=env, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        data, _ = p.communicate(timeout=timeout)
        if p.returncode != 0:
            raise CommandFailure(p.returncode)
        return data
    except BaseException:
        if p.poll() is None:
            try:
                os.killpg(p.pid, signal.SIGTERM)
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(p.pid, signal.SIGKILL)
                    p.wait(timeout=5)
                except (OSError, subprocess.TimeoutExpired):
                    pass
            except OSError:
                pass
        raise


def paths():
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve()
    app = workspace / 'app-source'
    root = Path(os.environ['RUNNER_TEMP']).resolve() / 'vending-ios-capture'
    return app, root


def load_state(root):
    p = root / 'state.json'
    state = json.loads(p.read_text()) if p.exists() else {'devices': []}
    need(isinstance(state, dict))
    return state


def save_state(root, state):
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    (root / 'state.json').write_text(json.dumps(state))


def cleanup(app, root):
    global ACTIVE_PHASE
    ACTIVE_PHASE = 'cleanup'
    failed = False
    state = {}
    try:
        state = load_state(root)
        devices = state.get('devices', [])
        need(isinstance(devices, list) and len(devices) <= 2)
        for index, device in enumerate(devices):
            target = TARGETS[index][0]
            try:
                with stage(target, 'inventory'):
                    inventory = json.loads(command(['xcrun', 'simctl', 'list', 'devices', '-j'], timeout=15))
                    found = [d for items in inventory['devices'].values() for d in items if d['udid'] == device]
                    need(len(found) == 1)
                if found[0].get('state') == 'Shutdown':
                    continue  # Do not send boot-only operations to a stopped device.
                for operation, args in (('terminate', ['terminate', device, BUNDLE]), ('clear', ['location', device, 'clear'])):
                    try:
                        with stage(target, operation):
                            command(['xcrun', 'simctl', *args], timeout=15)
                    except Exception:
                        pass  # Final Shutdown state, rather than this exit, decides containment.
                with stage(target, 'shutdown'):
                    command(['xcrun', 'simctl', 'shutdown', device], timeout=30)
                with stage(target, 'inventory'):
                    inventory = json.loads(command(['xcrun', 'simctl', 'list', 'devices', '-j'], timeout=15))
                    found = [d for items in inventory['devices'].values() for d in items if d['udid'] == device]
                    need(len(found) == 1 and found[0].get('state') == 'Shutdown')
            except Exception:
                failed = True
    except Exception:
        failed = True
    finally:
        # Separate marker survives a corrupt state.json; never remove an unowned file.
        if (root / 'services-owned').exists() or state.get('services_owned'):
            try:
                with stage('cleanup', 'settings'):
                    (app / 'ios/Flutter/LocalServices.xcconfig').unlink(missing_ok=True)
                    (root / 'services-owned').unlink(missing_ok=True)
            except Exception:
                failed = True
    state['local_cleanup_complete'] = not failed
    try:
        save_state(root, state)
    except Exception:
        failed = True
    need(not failed)


def boot_probe(app, root):
    # Before any app build/credentials: Simulator services only, no app installed/launched.
    for (label, _, _), device in zip(TARGETS, load_state(root)['devices']):
        with stage(label, 'boot'):
            command(['xcrun', 'simctl', 'boot', device], timeout=30)
        with stage(label, 'bootstatus'):
            command(['xcrun', 'simctl', 'bootstatus', device, '-b'], timeout=120)
        with stage(label, 'shutdown'):
            command(['xcrun', 'simctl', 'shutdown', device], timeout=30)
    # Re-read confirms both were stopped before expensive build.
    preflight(app, root)


def preflight(app, root):
    need(sys.platform == 'darwin')
    need(command(['git', 'rev-parse', 'HEAD'], cwd=app).decode().strip() == SOURCE)
    need(hashlib.sha256((app / 'ios/Podfile.lock').read_bytes()).hexdigest() == LOCK)
    need(re.search(r'^version: 1\.0\.0\+21\s*$', (app / 'pubspec.yaml').read_text(), re.M))
    # Do not assume client config exists in the fixed public checkout.
    client = app / 'lib/firebase_options.dart'
    need(client.exists())  # BLOCKING if absent; do not copy private files automatically.
    text = client.read_text()
    need(APP_ID in text and 'vendingnavi' in text)
    need(not (app / 'ios/Flutter/LocalServices.xcconfig').exists())
    devices = json.loads(command(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
    matches = []
    for _, name, _ in TARGETS:
        found = [d for d in devices.get(RUNTIME, []) if d['name'] == name and d.get('isAvailable')]
        need(len(found) == 1 and found[0]['state'] == 'Shutdown')
        matches.append(found[0]['udid'])
    save_state(root, {'devices': matches, 'services_owned': False})


def build(app, root):
    values = {key: os.environ.get(key, '') for key in SERVICES}
    need(all(values.values()))
    need(all('\n' not in v and '\r' not in v for v in values.values()))
    settings = app / 'ios/Flutter/LocalServices.xcconfig'
    need(not settings.exists())
    state = load_state(root)
    state['services_owned'] = True
    save_state(root, state)
    (root / 'services-owned').write_text('owned')
    try:
        fd = os.open(settings, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(fd, 'w') as f:
            f.write(''.join(f'{key} = {values[key]}\n' for key in SERVICES))
        command(['node', 'tool/check_ios_runtime_config.cjs'], cwd=app)
        # No signing/export/upload. Build environment has only existing runtime client settings.
        command(['flutter', 'build', 'ios', '--simulator', '--debug', '--no-pub',
                 '--dart-define=APP_ENTRY=v2', '--build-name=1.0.0', '--build-number=25'],
                cwd=app, timeout=1320)
        product = app / 'build/ios/iphonesimulator/Runner.app'
        command(['node', 'tool/check_ios_runtime_config.cjs', '--built-plist',
                 str(product / 'Info.plist')], cwd=app)
        command(['git', 'diff', '--exit-code', '--', 'pubspec.yaml', 'pubspec.lock', 'ios/Podfile.lock'], cwd=app)
    finally:
        primary_failure = sys.exc_info()[0] is not None
        try:
            settings.unlink(missing_ok=True)
        except Exception:
            safe_print('owned_settings_removal_failed')
            if not primary_failure:
                raise RuntimeError('Owned settings cleanup failed') from None


def capture(app, root):
    need(bounded_timeout(480) >= 479)  # Reserve eight minutes before starting either device.
    token = os.environ.get('APP_CHECK_DEBUG_TOKEN', '')
    need(re.fullmatch(r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}', token))
    product = app / 'build/ios/iphonesimulator/Runner.app'
    with (product / 'Info.plist').open('rb') as f:
        info = plistlib.load(f)
    need(info.get('CFBundleIdentifier') == BUNDLE)
    need(info.get('CFBundleShortVersionString') == '1.0.0' and info.get('CFBundleVersion') == '25')
    need('iPhoneSimulator' in info.get('CFBundleSupportedPlatforms', []))
    state = load_state(root)
    need(len(state.get('devices', [])) == 2)
    output = root / 'output'
    output.mkdir(mode=0o700, exist_ok=False)
    receipts = []
    try:
        for (label, name, allowed), device in zip(TARGETS, state['devices']):
            need(bounded_timeout(180) >= 179)
            with stage(label, 'boot'):
                command(['xcrun', 'simctl', 'boot', device])
            with stage(label, 'bootstatus'):
                command(['xcrun', 'simctl', 'bootstatus', device, '-b'], timeout=180)
            with stage(label, 'install'):
                command(['xcrun', 'simctl', 'install', device, str(product)])
            with stage(label, 'permission'):
                command(['xcrun', 'simctl', 'privacy', device, 'grant', 'location', BUNDLE])
            # Explicit public Tokyo-area simulation; not the owner's precise position.
            with stage(label, 'location'):
                command(['xcrun', 'simctl', 'location', device, 'set', '35.68,139.76'])
            child = dict(os.environ)
            child.pop('APP_CHECK_DEBUG_TOKEN', None)
            child['SIMCTL_CHILD_AppCheckDebugToken'] = token
            try:
                with stage(label, 'launch'):
                    command(['xcrun', 'simctl', 'launch', '--terminate-running-process', device, BUNDLE], env=child)
            finally:
                child.pop('SIMCTL_CHILD_AppCheckDebugToken', None)
            with stage(label, 'wait'):
                need(bounded_timeout(30) >= 29)
                time.sleep(30)  # Not proof that guest UI/maps have loaded.
            png = output / f'{label}.png'
            with stage(label, 'screenshot'):
                command(['xcrun', 'simctl', 'io', device, 'screenshot', str(png)])
            with stage(label, 'dimensions'):
                data = png.read_bytes()
                need(data[:8] == bytes([137, 80, 78, 71, 13, 10, 26, 10]))
                width, height = struct.unpack('>II', data[16:24])
                need((width, height) in allowed)
            receipts.append({'file': png.name, 'device': name, 'runtime': RUNTIME,
                             'width': width, 'height': height,
                             'sha256': hashlib.sha256(data).hexdigest(),
                             'app_source': SOURCE, 'build': '1.0.0 (25) Simulator debug',
                             'location': 'simulated public Tokyo area; not owner location',
                             'visual_review': 'PENDING: genuine loaded guest UI, no error/popup or personal data; not ASC-approved'})
            with stage(label, 'terminate'):
                command(['xcrun', 'simctl', 'terminate', device, BUNDLE])
            with stage(label, 'shutdown'):
                command(['xcrun', 'simctl', 'shutdown', device])
        (output / 'receipt.json').write_text(json.dumps(receipts, indent=2))
        need({p.name for p in output.iterdir()} == {'ipad13.png', 'iphone-dynamic-medium.png', 'receipt.json'})
    finally:
        token = ''
        # main's failure path and the workflow always-step own cleanup; do not
        # overwrite a primary capture exception with a secondary cleanup error.


def interrupted(*_):
    raise RuntimeError('Interrupted; local cleanup requested')


def main():
    global DIAGNOSTIC_ROOT, DEADLINE_START, ACTIVE_PHASE
    need(len(sys.argv) == 2 and sys.argv[1] in {'preflight', 'boot_probe', 'build', 'capture', 'cleanup'})
    action = sys.argv[1]
    app, root = paths()
    DIAGNOSTIC_ROOT = root / 'diagnostics'
    restore_diagnostics()
    ACTIVE_PHASE = 'preflight' if action == 'boot_probe' else action
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, interrupted)
    try:
        DEADLINE_START = float((root / 'budget-start').read_text())
        need(0 <= time.monotonic() - DEADLINE_START < 45 * 60)
        if action == 'capture':
            with stage('capture', 'start'):
                capture(app, root)
        else:
            globals()[action](app, root)
        safe_print(f'Capture phase {action}: complete; external cleanup remains manual')
    except BaseException:
        if action != 'cleanup':
            try:
                cleanup(app, root)
            except BaseException:
                pass
        # Do not print exception/body/command output: SDKs may contain credential values.
        safe_print(f'Capture phase {action}: failed; no retry, inspect blockers and perform manual external cleanup')
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
