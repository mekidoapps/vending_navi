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
    # No stdout/stderr, token or SDK logs are forwarded to Actions logs/artifacts.
    p = subprocess.Popen(args, cwd=cwd, env=env, stdout=subprocess.PIPE,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    try:
        data, _ = p.communicate(timeout=timeout)
        need(p.returncode == 0)
        return data
    except BaseException:
        try:
            os.killpg(p.pid, signal.SIGTERM)
            p.wait(timeout=5)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(p.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
        raise


def paths():
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve()
    app = workspace / 'app-source'
    root = Path(os.environ['RUNNER_TEMP']).resolve() / 'vending-ios-capture'
    return app, root


def load_state(root):
    p = root / 'state.json'
    return json.loads(p.read_text()) if p.exists() else {'devices': []}


def save_state(root, state):
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    (root / 'state.json').write_text(json.dumps(state))


def cleanup(app, root):
    failed = False
    for device in load_state(root).get('devices', []):
        for args in (['terminate', device, BUNDLE], ['location', device, 'clear']):
            try:
                command(['xcrun', 'simctl', *args], timeout=25)
            except RuntimeError:
                # App may never have launched; bounded shutdown below remains required.
                pass
        try:
            inventory = json.loads(command(['xcrun', 'simctl', 'list', 'devices', '-j']))
            found = [d for items in inventory['devices'].values() for d in items if d['udid'] == device]
            if found and found[0].get('state') != 'Shutdown':
                command(['xcrun', 'simctl', 'shutdown', device], timeout=45)
        except RuntimeError:
            failed = True
    state = load_state(root)
    if state.get('services_owned'):
        (app / 'ios/Flutter/LocalServices.xcconfig').unlink(missing_ok=True)
    state['local_cleanup_complete'] = not failed
    save_state(root, state)
    need(not failed)


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
    try:
        fd = os.open(settings, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        with os.fdopen(fd, 'w') as f:
            f.write(''.join(f'{key} = {values[key]}\n' for key in SERVICES))
        command(['node', 'tool/check_ios_runtime_config.cjs'], cwd=app)
        # No signing/export/upload. Build environment has only existing runtime client settings.
        command(['flutter', 'build', 'ios', '--simulator', '--debug', '--no-pub',
                 '--dart-define=APP_ENTRY=v2', '--build-name=1.0.0', '--build-number=25'],
                cwd=app, timeout=1800)
        product = app / 'build/ios/iphonesimulator/Runner.app'
        command(['node', 'tool/check_ios_runtime_config.cjs', '--built-plist',
                 str(product / 'Info.plist')], cwd=app)
        command(['git', 'diff', '--exit-code', '--', 'pubspec.yaml', 'pubspec.lock', 'ios/Podfile.lock'], cwd=app)
    finally:
        settings.unlink(missing_ok=True)


def capture(app, root):
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
            command(['xcrun', 'simctl', 'boot', device])
            command(['xcrun', 'simctl', 'bootstatus', device, '-b'], timeout=180)
            command(['xcrun', 'simctl', 'install', device, str(product)])
            command(['xcrun', 'simctl', 'privacy', device, 'grant', 'location', BUNDLE])
            # Explicit public Tokyo-area simulation; not the owner's precise position.
            command(['xcrun', 'simctl', 'location', device, 'set', '35.68,139.76'])
            child = dict(os.environ)
            child.pop('APP_CHECK_DEBUG_TOKEN', None)
            child['SIMCTL_CHILD_AppCheckDebugToken'] = token
            command(['xcrun', 'simctl', 'launch', '--terminate-running-process', device, BUNDLE], env=child)
            child.pop('SIMCTL_CHILD_AppCheckDebugToken', None)
            time.sleep(30)  # Bounded initial guest UI loading; never a claim that data has loaded.
            png = output / f'{label}.png'
            command(['xcrun', 'simctl', 'io', device, 'screenshot', str(png)])
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
            command(['xcrun', 'simctl', 'terminate', device, BUNDLE])
            command(['xcrun', 'simctl', 'shutdown', device])
        (output / 'receipt.json').write_text(json.dumps(receipts, indent=2))
        need({p.name for p in output.iterdir()} == {'ipad13.png', 'iphone-dynamic-medium.png', 'receipt.json'})
    finally:
        token = ''
        cleanup(app, root)


def interrupted(*_):
    raise RuntimeError('Interrupted; local cleanup requested')


def main():
    need(len(sys.argv) == 2 and sys.argv[1] in {'preflight', 'build', 'capture', 'cleanup'})
    action = sys.argv[1]
    app, root = paths()
    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, interrupted)
    try:
        globals()[action](app, root)
        print(f'Capture phase {action}: complete; external cleanup remains manual')
    except BaseException:
        if action != 'cleanup':
            try:
                cleanup(app, root)
            except BaseException:
                pass
        # Do not print exception/body/command output: SDKs may contain credential values.
        print(f'Capture phase {action}: failed; no retry, inspect blockers and perform manual external cleanup', file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())