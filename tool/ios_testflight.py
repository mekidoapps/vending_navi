"""Hosted macOS only: unsigned build, fresh-runner signing, fresh-runner upload."""
import base64
import datetime
import hashlib
import hmac
import json
import os
from pathlib import Path
import plistlib
import re
import secrets
import shlex
import shutil
import signal
import stat
import subprocess
import sys
import zipfile

TEAM = 'HBD765T7G9'
BUNDLE = 'com.mekidoapps.vendingnavi'
PROFILE_NAME = 'VendingNavi AppStore'
LOCK_SHA256 = '3d9233f72b9f70f73f4f6482bf50510049ad37d94cf24f80ccaf8859331a7b96'
SERVICES = ('GOOGLE_MAPS_IOS_API_KEY', 'GOOGLE_SIGN_IN_IOS_CLIENT_ID',
            'GOOGLE_SIGN_IN_REVERSED_CLIENT_ID')
ROOT = Path(__file__).resolve().parent.parent


def require(ok):
    if not ok:
        raise ValueError('Release prerequisite failed')


def work():
    require(sys.platform == 'darwin' and os.environ.get('GITHUB_ACTIONS') == 'true')
    temp = Path(os.environ['RUNNER_TEMP']).resolve()
    require(temp.is_absolute() and temp != Path('/'))
    return temp / 'vendingnavi-testflight'


def child_environment():
    # No inherited credential variables, GITHUB_ENV, token or arbitrary overrides.
    allowed = ('PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'DEVELOPER_DIR',
               'FLUTTER_ROOT', 'PUB_CACHE', 'COCOAPODS_DISABLE_STATS')
    return {name: os.environ[name] for name in allowed if name in os.environ}


def command(args, *, output=False, cwd=ROOT, extra_env=None, timeout=600):
    env = child_environment()
    env.update(extra_env or {})
    # Expanded settings and tool diagnostics must never enter public Actions logs.
    result = subprocess.run(args, cwd=cwd, env=env, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, timeout=timeout, check=False)
    require(result.returncode == 0)
    return result.stdout if output else None


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def guard():
    require(os.environ.get('GITHUB_REPOSITORY') == 'mekidoapps/vending_navi')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/ios/device-configuration')
    require(os.environ.get('ALLOWED_BRANCH') == 'ios/device-configuration')
    require(os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch')
    require(os.environ.get('GITHUB_RUN_ATTEMPT') == '1')
    require(os.environ.get('SERVICES_CONFIRMED') == 'true')
    expected = os.environ['EXPECTED_SHA']
    require(re.fullmatch(r'[0-9a-f]{40}', expected))
    require(expected == os.environ['GITHUB_SHA'])
    require(command(['git', 'rev-parse', 'HEAD'], output=True).decode().strip() == expected)
    require(re.fullmatch(r'[1-9][0-9]{0,8}', os.environ['BUILD_NUMBER']))
    require(sha256(ROOT / 'ios/Podfile.lock') == LOCK_SHA256)
    require(re.search(r'^version: 1\.0\.0\+21\s*$', (ROOT / 'pubspec.yaml').read_text(), re.M))
    require(os.environ['DEVELOPER_DIR'] == '/Applications/Xcode_26.3.app/Contents/Developer')
    require(Path(os.environ['DEVELOPER_DIR']).is_dir())
    require(b'Xcode 26.3' in command(['xcodebuild', '-version'], output=True))
    require(int(command(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'],
                        output=True).decode().split('.')[0]) >= 26)


def receipt_identity():
    return {'source': os.environ['EXPECTED_SHA'], 'build': os.environ['BUILD_NUMBER'],
            'run': os.environ['GITHUB_RUN_ID'], 'bundle': BUNDLE}


def validate_info(info):
    require(info.get('CFBundleIdentifier') == BUNDLE)
    require(info.get('CFBundleDisplayName') == '自販機ナビ')
    require(info.get('CFBundleShortVersionString') == '1.0.0')
    require(info.get('CFBundleVersion') == os.environ['BUILD_NUMBER'])
    key = info.get('GoogleMapsAPIKey', '')
    client = info.get('GIDClientID', '')
    require(re.fullmatch(r'AIza[A-Za-z0-9_-]{35}', key))
    match = re.fullmatch(r'([A-Za-z0-9_-]+)\.apps\.googleusercontent\.com', client)
    require(match)
    schemes = [scheme for entry in info.get('CFBundleURLTypes', [])
               for scheme in entry.get('CFBundleURLSchemes', [])]
    require('com.googleusercontent.apps.' + match[1] in schemes)
    # Client settings intentionally ship in the binary; only hashes enter receipts.
    return hashlib.sha256(json.dumps([key, client, schemes], sort_keys=True).encode()).hexdigest()


def app_info(app):
    with (Path(app) / 'Info.plist').open('rb') as stream:
        return plistlib.load(stream)


def build():
    guard()
    target = work()
    require(not target.exists())
    target.mkdir(mode=0o700)
    services = ROOT / 'ios/Flutter/LocalServices.xcconfig'
    require(not services.exists())
    (target / 'services-owned').touch()
    require(all(os.environ.get(name) for name in SERVICES))
    services.write_text(''.join(name + ' = ' + os.environ[name] + '\n' for name in SERVICES))
    try:
        command(['node', 'tool/check_ios_runtime_config.cjs'])
        command(['flutter', 'build', 'ipa', '--release', '--no-codesign', '--no-pub',
                 '--dart-define=APP_ENTRY=v2', '--build-name=1.0.0',
                 '--build-number=' + os.environ['BUILD_NUMBER']], timeout=1650)
        command(['git', 'diff', '--exit-code', '--', 'pubspec.yaml', 'pubspec.lock', 'ios/Podfile.lock'])
        archive = ROOT / 'build/ios/archive/Runner.xcarchive'
        app = archive / 'Products/Applications/Runner.app'
        command(['node', 'tool/check_ios_runtime_config.cjs', '--built-plist', str(app / 'Info.plist')])
        receipt = receipt_identity()
        receipt['services_sha256'] = validate_info(app_info(app))
        payload = target / 'payload'
        payload.mkdir()
        shutil.move(str(archive), str(payload / 'Runner.xcarchive'))
        (payload / 'receipt.json').write_text(json.dumps(receipt))
    finally:
        services.unlink(missing_ok=True)


def context(kind):
    return json.dumps([kind, receipt_identity()], sort_keys=True).encode()


def transfer_keys():
    encoded = os.environ['IOS_CI_TRANSFER_KEY_BASE64']
    raw = base64.b64decode(encoded, validate=True)
    require(len(raw) == 32)
    # Independent encryption-password and authentication keys from a 256-bit master.
    return (hmac.digest(raw, b'vendingnavi-encryption-v1', 'sha256').hex(),
            hmac.digest(raw, b'vendingnavi-authentication-v1', 'sha256'))


def mac_file(path, key, kind):
    digest = hmac.new(key, context(kind), hashlib.sha256)
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def seal(kind):
    target = work()
    payload = target / 'payload'
    require(payload.is_dir())
    if kind == 'ipa':
        require(not (target / 'keychains.json').exists())
    plain = target / 'transfer.zip'
    command(['ditto', '-c', '-k', '--norsrc', '--keepParent', str(payload), str(plain)])
    directory = target / 'transfer'
    directory.mkdir(exist_ok=True)
    password, mac_key = transfer_keys()
    encrypted = directory / (kind + '.enc')
    try:
        command(['openssl', 'enc', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-salt',
                 '-in', str(plain), '-out', str(encrypted), '-pass', 'env:VN_TRANSFER_PASSWORD'],
                extra_env={'VN_TRANSFER_PASSWORD': password})
        (directory / (kind + '.mac')).write_text(mac_file(encrypted, mac_key, kind))
    finally:
        plain.unlink(missing_ok=True)
    shutil.rmtree(payload)


def validate_zip(archive, roots=('payload',)):
    total = 0
    seen = set()
    for member in archive.infolist():
        name = member.filename
        canonical = name.rstrip('/').casefold()
        require(canonical not in seen)
        seen.add(canonical)
        require(name.split('/')[0] in roots and '\\' not in name)
        require(not any(part in ('.', '..') for part in name.split('/')))
        total += member.file_size
        require(total < 4 * 1024 ** 3)
        mode = member.external_attr >> 16
        # iOS frameworks are flat. Reject links/special files rather than allowing
        # a build-produced symlink chain to escape on a credential-bearing runner.
        require(stat.S_IFMT(mode) in (0, stat.S_IFREG, stat.S_IFDIR))
    require(len(seen) <= 100000)


def extract_zip(archive, destination, roots=('payload',)):
    validate_zip(archive, roots)
    destination = Path(destination).resolve()
    for member in archive.infolist():
        path = destination / member.filename
        require(path.resolve().is_relative_to(destination))
        if member.is_dir():
            path.mkdir(mode=0o700, parents=True, exist_ok=True)
        else:
            path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
            with archive.open(member) as source, path.open('xb') as output:
                shutil.copyfileobj(source, output)
            path.chmod((member.external_attr >> 16) & 0o777 or 0o600)


def open_transfer(kind):
    target = work()
    directory = target / 'transfer'
    password, mac_key = transfer_keys()
    encrypted = directory / (kind + '.enc')
    require(hmac.compare_digest((directory / (kind + '.mac')).read_text(),
                                mac_file(encrypted, mac_key, kind)))
    plain = target / 'transfer.zip'
    require(not (target / 'payload').exists())
    try:
        command(['openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-iter', '200000',
                 '-in', str(encrypted), '-out', str(plain), '-pass', 'env:VN_TRANSFER_PASSWORD'],
                extra_env={'VN_TRANSFER_PASSWORD': password})
        with zipfile.ZipFile(plain) as archive:
            extract_zip(archive, target)
        receipt = json.loads((target / 'payload/receipt.json').read_text())
        require(all(receipt.get(key) == value for key, value in receipt_identity().items()))
        if kind == 'archive':
            require(validate_info(app_info(target / 'payload/Runner.xcarchive/Products/Applications/Runner.app'))
                    == receipt['services_sha256'])
        else:
            require(sha256(target / 'payload/Runner.ipa') == receipt['ipa_sha256'])
    finally:
        plain.unlink(missing_ok=True)


def profile_directories():
    return (Path.home() / 'Library/MobileDevice/Provisioning Profiles',
            Path.home() / 'Library/Developer/Xcode/UserData/Provisioning Profiles')


def decode(name, path):
    path.write_bytes(base64.b64decode(''.join(os.environ[name].split()), validate=True))
    path.chmod(0o600)
    require(path.stat().st_size > 0)


def validate_profile(profile, now):
    require(profile.get('Name') == PROFILE_NAME)
    require(profile.get('TeamIdentifier') == [TEAM])
    require(profile.get('ApplicationIdentifierPrefix') == [TEAM])
    require(profile.get('ExpirationDate') > now + datetime.timedelta(hours=2))
    require(profile.get('CreationDate') <= now)
    require(not profile.get('ProvisionedDevices') and not profile.get('ProvisionsAllDevices'))
    ent = profile['Entitlements']
    require(ent.get('application-identifier') == TEAM + '.' + BUNDLE)
    require(ent.get('com.apple.developer.team-identifier') == TEAM)
    require(ent.get('get-task-allow') is False and ent.get('beta-reports-active') is True)
    require(re.fullmatch(r'[0-9A-Fa-f-]{36}', profile['UUID']))


def distribution_identity(profile, identities):
    hashes = re.findall(r'\b([0-9A-F]{40}) "Apple Distribution:[^"\n]+\(' + TEAM + r'\)"', identities)
    require(len(hashes) == 1)
    fingerprint = hashes[0]
    require(fingerprint in [hashlib.sha1(cert).hexdigest().upper()
                           for cert in profile['DeveloperCertificates']])
    return fingerprint


def cleanup_signing():
    target = work()
    if not target.exists():
        return
    failed = False
    original = target / 'keychains.json'
    if original.exists():
        try:
            command(['security', 'list-keychains', '-d', 'user', '-s',
                     *json.loads(original.read_text())])
        except Exception:
            failed = True
    keychain = target / 'signing.keychain-db'
    if keychain.exists():
        try:
            command(['security', 'delete-keychain', str(keychain)])
        except Exception:
            failed = True
    marker = target / 'installed-profile.txt'
    if marker.exists():
        try:
            uuid = marker.read_text()
            require(re.fullmatch(r'[0-9A-Fa-f-]{36}', uuid))
            for directory in profile_directories():
                (directory / (uuid + '.mobileprovision')).unlink(missing_ok=True)
        except Exception:
            failed = True
    for name in ('certificate.p12', 'profile.mobileprovision', 'ExportOptions.plist'):
        try:
            (target / name).unlink(missing_ok=True)
        except Exception:
            failed = True
    require(not failed)
    original.unlink(missing_ok=True)
    marker.unlink(missing_ok=True)


def verify_ipa(ipa, receipt, expected_uuid=None, expected_fingerprint=None):
    target = work()
    unpacked = target / 'verified-ipa'
    require(not unpacked.exists())
    # Xcode-generated IPA is never executed; only native signature/plist checks.
    with zipfile.ZipFile(ipa) as archive:
        extract_zip(archive, unpacked, ('Payload', 'SwiftSupport', 'Symbols', 'BCSymbolMaps'))
    try:
        apps = list((unpacked / 'Payload').glob('*.app'))
        require(len(apps) == 1)
        app = apps[0]
        require(validate_info(app_info(app)) == receipt['services_sha256'])
        command(['codesign', '--verify', '--deep', '--strict', str(app)])
        profile = plistlib.loads(command(['security', 'cms', '-D', '-i',
                                         str(app / 'embedded.mobileprovision')], output=True))
        validate_profile(profile, datetime.datetime.utcnow())
        require(expected_uuid is None or profile['UUID'] == expected_uuid)
        ent = plistlib.loads(command(['codesign', '-d', '--entitlements', ':-', str(app)], output=True))
        require(ent.get('application-identifier') == TEAM + '.' + BUNDLE)
        require(ent.get('com.apple.developer.team-identifier') == TEAM)
        require(ent.get('get-task-allow', False) is False)
        prefix = target / 'signer-cert'
        try:
            command(['codesign', '-d', '--extract-certificates', str(prefix), str(app)])
            fingerprint = hashlib.sha1(Path(str(prefix) + '0').read_bytes()).hexdigest().upper()
            require(fingerprint in [hashlib.sha1(cert).hexdigest().upper()
                                    for cert in profile['DeveloperCertificates']])
            require(expected_fingerprint is None or fingerprint == expected_fingerprint)
        finally:
            for certificate in target.glob('signer-cert*'):
                certificate.unlink()
    finally:
        shutil.rmtree(unpacked)


def sign():
    guard()
    target = work()
    payload = target / 'payload'
    archive = payload / 'Runner.xcarchive'
    receipt = json.loads((payload / 'receipt.json').read_text())
    require(validate_info(app_info(archive / 'Products/Applications/Runner.app')) == receipt['services_sha256'])
    try:
        decode('IOS_DISTRIBUTION_P12_BASE64', target / 'certificate.p12')
        decode('IOS_APPSTORE_PROFILE_BASE64', target / 'profile.mobileprovision')
        profile = plistlib.loads(command(['security', 'cms', '-D', '-i',
                                         str(target / 'profile.mobileprovision')], output=True))
        validate_profile(profile, datetime.datetime.utcnow())
        keychain = target / 'signing.keychain-db'
        require(not keychain.exists() and not (target / 'keychains.json').exists())
        old = shlex.split(command(['security', 'list-keychains', '-d', 'user'], output=True).decode())
        (target / 'keychains.json').write_text(json.dumps(old))
        password = secrets.token_urlsafe(32)
        command(['security', 'create-keychain', '-p', password, str(keychain)])
        command(['security', 'set-keychain-settings', '-lut', '900', str(keychain)])
        command(['security', 'unlock-keychain', '-p', password, str(keychain)])
        command(['security', 'import', str(target / 'certificate.p12'), '-P',
                 os.environ['IOS_DISTRIBUTION_P12_PASSWORD'], '-k', str(keychain),
                 '-T', '/usr/bin/codesign'])
        (target / 'certificate.p12').unlink()
        command(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:',
                 '-s', '-k', password, str(keychain)])
        command(['security', 'list-keychains', '-d', 'user', '-s', str(keychain), *old])
        identities = command(['security', 'find-identity', '-v', '-p', 'codesigning',
                              str(keychain)], output=True).decode()
        fingerprint = distribution_identity(profile, identities)
        uuid = profile['UUID']
        require(all(not (directory / (uuid + '.mobileprovision')).exists()
                    for directory in profile_directories()))
        (target / 'installed-profile.txt').write_text(uuid)
        for directory in profile_directories():
            directory.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target / 'profile.mobileprovision', directory / (uuid + '.mobileprovision'))
        options = {'method': 'app-store-connect', 'destination': 'export', 'teamID': TEAM,
                   'signingStyle': 'manual', 'signingCertificate': fingerprint,
                   'provisioningProfiles': {BUNDLE: PROFILE_NAME},
                   'manageAppVersionAndBuildNumber': False, 'uploadSymbols': False}
        with (target / 'ExportOptions.plist').open('wb') as stream:
            plistlib.dump(options, stream)
        # No Flutter, pod, Ruby, project build or provisioning update in this job.
        command(['xcodebuild', '-exportArchive', '-archivePath', str(archive),
                 '-exportPath', str(target / 'export'),
                 '-exportOptionsPlist', str(target / 'ExportOptions.plist')], timeout=600)
        ipas = list((target / 'export').glob('*.ipa'))
        require(len(ipas) == 1)
        verify_ipa(ipas[0], receipt, uuid, fingerprint)
        shutil.rmtree(archive)
        shutil.move(str(ipas[0]), str(payload / 'Runner.ipa'))
        receipt['ipa_sha256'] = sha256(payload / 'Runner.ipa')
        receipt['profile_uuid'] = uuid
        receipt['signing_sha1'] = fingerprint
        (payload / 'receipt.json').write_text(json.dumps(receipt))
    finally:
        # Must succeed before any encrypted IPA artifact or upload job can proceed.
        cleanup_signing()


def upload():
    guard()
    target = work()
    receipt = json.loads((target / 'payload/receipt.json').read_text())
    ipa = target / 'payload/Runner.ipa'
    require(sha256(ipa) == receipt['ipa_sha256'])
    verify_ipa(ipa, receipt, receipt['profile_uuid'], receipt['signing_sha1'])
    key_id = os.environ['ASC_API_KEY_ID']
    issuer = os.environ['ASC_API_ISSUER_ID']
    require(re.fullmatch(r'[A-Z0-9]{10}', key_id))
    require(re.fullmatch(r'[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', issuer))
    keys = target / 'private_keys'
    require(not keys.exists())
    keys.mkdir(mode=0o700)
    try:
        key = keys / ('AuthKey_' + key_id + '.p8')
        decode('ASC_API_KEY_P8_BASE64', key)
        command(['openssl', 'pkey', '-in', str(key), '-check', '-noout'])
        command(['xcrun', 'altool', '--upload-app', '--type', 'ios', '--file', str(ipa),
                 '--apiKey', key_id, '--apiIssuer', issuer], cwd=target, timeout=480)
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
            summary.write('Apple upload command accepted; processing/tester availability unverified.\n'
                          + 'Source: ' + os.environ['EXPECTED_SHA'] + '\n'
                          + 'Version: 1.0.0 (' + os.environ['BUILD_NUMBER'] + '); APP_ENTRY=v2\n')
    finally:
        shutil.rmtree(keys)


def cleanup():
    target = work()
    if not target.exists():
        return
    cleanup_signing()
    if (target / 'services-owned').exists():
        (ROOT / 'ios/Flutter/LocalServices.xcconfig').unlink(missing_ok=True)
    shutil.rmtree(target)
    if (ROOT / 'build/ios').exists():
        shutil.rmtree(ROOT / 'build/ios')


def main():
    os.umask(0o077)
    require(len(sys.argv) == 2)
    for signum in (signal.SIGINT, signal.SIGTERM):
        signal.signal(signum, lambda *_: sys.exit(1))
    mode = sys.argv[1]
    commands = {'guard': guard, 'build': build, 'sign': sign, 'upload': upload,
                'seal-archive': lambda: seal('archive'), 'open-archive': lambda: open_transfer('archive'),
                'seal-ipa': lambda: seal('ipa'), 'open-ipa': lambda: open_transfer('ipa'), 'cleanup': cleanup}
    require(mode in commands)
    try:
        commands[mode]()
    except BaseException:
        if mode != 'guard':
            cleanup()
        raise


if __name__ == '__main__':
    try:
        main()
    except BaseException:
        print('TestFlight stage failed or was interrupted; tool output and values withheld.', file=sys.stderr)
        sys.exit(1)
