"""Offline native-asset and UTF-8 checks. Never reads signing material."""
import hashlib
import json
from pathlib import Path
import plistlib
import struct
import subprocess

ROOT = Path(__file__).resolve().parent.parent
def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT)

source = ROOT / 'assets/icons/appicon.png'
assert git('hash-object', str(source)).strip() == git('rev-parse', 'HEAD:assets/icons/appicon.png').strip()
assert b'image_path: "assets/icons/appicon.png"' in (ROOT / 'pubspec.yaml').read_bytes()
catalog_dir = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
catalog = json.loads((catalog_dir / 'Contents.json').read_text(encoding='utf-8'))
for item in catalog['images']:
    data = (catalog_dir / item['filename']).read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n' and data[12:16] == b'IHDR'
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    expected = round(float(item['size'].split('x')[0]) * float(item['scale'][:-1]))
    assert (width, height) == (expected, expected), item['filename']
    assert depth == 8 and color == 2, 'App icons must be opaque RGB PNGs'

entitlements = plistlib.loads((ROOT / 'ios/Runner/Runner.entitlements').read_bytes())
assert entitlements == {'com.apple.developer.applesignin': ['Default']}
project = (ROOT / 'ios/Runner.xcodeproj/project.pbxproj').read_text(encoding='utf-8')
assert project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;') == 3
info = plistlib.loads((ROOT / 'ios/Runner/Info.plist').read_bytes())
assert info['CFBundleDisplayName'] == '\u81ea\u8ca9\u6a5f\u30ca\u30d3'

# Inspect exactly the implementation diff, including new files; PNGs stay binary.
changed = set(git('diff', '--name-only', '-z').decode('utf-8', errors='strict').split('\0'))
changed.update(git('ls-files', '--others', '--exclude-standard', '-z').decode('utf-8', errors='strict').split('\0'))
changed.discard('')
for name in changed:
    path = ROOT / name
    if path.suffix != '.png':
        text = path.read_bytes().decode('utf-8', errors='strict')
        assert '\ufffd' not in text, name
    assert not name.startswith(('android/', 'linux/', 'macos/', 'windows/', '.github/')), name
assert not {'pubspec.yaml', 'pubspec.lock', 'ios/Podfile.lock'} & changed
print('PASS: canonical Android artwork unchanged; all ' + str(len(catalog['images'])) +
      ' iOS catalog entries have exact dimensions/opaque RGB; all 3 build configs have Apple entitlement; real Japanese display name; changed text strict UTF-8/no replacement characters; Android/other platforms/locks/workflow YAML unchanged.')
print('Canonical artwork SHA256: ' + hashlib.sha256(source.read_bytes()).hexdigest())
