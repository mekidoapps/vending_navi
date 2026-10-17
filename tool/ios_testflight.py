"""Hosted macOS only: unsigned build, fresh-runner signing, fresh-runner upload."""
import base64
from contextlib import contextmanager
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


class SigningStageError(ValueError):
    """Contains a fixed stage label, never tool output or credential data."""
    def __init__(self, stage, category='validation'):
        self.category = category if category in DIAGNOSTIC_CATEGORIES else 'unexpected'
        super().__init__(stage)



DIAGNOSTIC_CATEGORIES = frozenset({
    'validation', 'invalid-plist', 'invalid-zip', 'local-io', 'unexpected',
    'interrupted', 'tool-timeout', 'tool-missing', 'tool-start-failed', 'tool-nonzero',
    'storage-full-marker', 'process-killed-marker', 'network-marker',
    'dart-compiler-marker', 'native-compiler-marker', 'dependency-marker',
    'signing-marker', 'export-marker', 'upload-auth-marker',
    'upload-duplicate-marker', 'upload-validation-marker',
})
DIAGNOSTIC_STAGES = frozenset({
    'app-and-signature',
    'build/app-info-and-receipt',
    'build/archive-path',
    'build/built-runtime-check',
    'build/flutter-archive',
    'build/guard',
    'build/locked-files-check',
    'build/package-archive',
    'build/remove-runtime-settings',
    'build/runtime-inputs',
    'build/runtime-settings-check',
    'build/workspace',
    'build/write-runtime-settings',
    'certificate-extract',
    'certificate-match',
    'cleanup-signing-material',
    'cleanup/build-material',
    'cleanup/runtime-settings',
    'cleanup/signing',
    'cleanup/workspace',
    'cleanup/workspace-material',
    'configure-keychain-access',
    'decode-p12',
    'decode-profile',
    'decode-profile-cms',
    'embedded-profile-decode',
    'embedded-profile-uuid',
    'embedded-profile-validation',
    'entitlements-extract',
    'entitlements-match',
    'entitlements-parse',
    'entry',
    'find-valid-distribution-identity',
    'guard-source-and-toolchain',
    'guard/dispatch-inputs',
    'guard/lock-and-version',
    'guard/sdk-version',
    'guard/source-head',
    'guard/toolchain-path',
    'guard/xcode-version',
    'import-distribution-p12',
    'install-appstore-profile',
    'ipa/remove-certificates',
    'ipa/remove-unpacked',
    'locate-exported-ipa',
    'match-profile-certificate',
    'open/authenticate',
    'open/decrypt',
    'open/payload-integrity',
    'open/receipt-identity',
    'open/remove-plaintext',
    'open/safe-extract',
    'open/transfer-key',
    'open/workspace',
    'prepare-export-options',
    'prepare-temporary-keychain',
    'record-verified-ipa',
    'seal/authenticate',
    'seal/encrypt',
    'seal/package',
    'seal/remove-payload',
    'seal/remove-plaintext',
    'seal/transfer-key',
    'seal/workspace',
    'upload/accepted-summary',
    'upload/api-identifiers',
    'upload/apple-submit-once',
    'upload/decode-api-key',
    'upload/guard',
    'upload/ipa-digest',
    'upload/key-directory',
    'upload/read-receipt',
    'upload/remove-api-key',
    'upload/validate-api-key',
    'upload/verify-ipa',
    'upload/workspace',
    'validate-appstore-profile',
    'validate-unsigned-archive',
    'verify-exported-ipa',
    'verify-exported-ipa/app-and-signature',
    'verify-exported-ipa/certificate-extract',
    'verify-exported-ipa/certificate-match',
    'verify-exported-ipa/embedded-profile-decode',
    'verify-exported-ipa/embedded-profile-uuid',
    'verify-exported-ipa/embedded-profile-validation',
    'verify-exported-ipa/entitlements-extract',
    'verify-exported-ipa/entitlements-match',
    'verify-exported-ipa/entitlements-parse',
    'xcode-export-archive',
})
CURRENT_STAGE = 'entry'


class ToolFailure(ValueError):
    def __init__(self, category):
        self.stage = CURRENT_STAGE
        self.category = category if category in DIAGNOSTIC_CATEGORIES else 'unexpected'
        super().__init__('Tool failed; output withheld')


class DiagnosticError(ValueError):
    def __init__(self, stage, category):
        self.stage = stage if stage in DIAGNOSTIC_STAGES else 'entry'
        self.category = category if category in DIAGNOSTIC_CATEGORIES else 'unexpected'
        super().__init__('Release diagnostics; values withheld')


def mark(stage):
    global CURRENT_STAGE
    require(stage in DIAGNOSTIC_STAGES)
    CURRENT_STAGE = stage
    print('TestFlight entering fixed stage: ' + stage, file=sys.stderr, flush=True)


@contextmanager
def cleanup_stage(stage):
    global CURRENT_STAGE
    previous = CURRENT_STAGE
    mark(stage)
    try:
        yield
    except BaseException as error:
        raise DiagnosticError(stage, error_category(error)) from None
    finally:
        # Successful cleanup must not replace the original failure's stage.
        CURRENT_STAGE = previous


def error_category(error):
    if isinstance(error, (ToolFailure, SigningStageError, DiagnosticError)):
        return error.category if error.category in DIAGNOSTIC_CATEGORIES else 'unexpected'
    if isinstance(error, (KeyboardInterrupt, SystemExit)):
        return 'interrupted'
    if isinstance(error, plistlib.InvalidFileException):
        return 'invalid-plist'
    if isinstance(error, zipfile.BadZipFile):
        return 'invalid-zip'
    if isinstance(error, OSError):
        return 'local-io'
    if isinstance(error, (ValueError, KeyError, TypeError)):
        return 'validation'
    return 'unexpected'


def classify_tool_failure(stdout, stderr):
    # Heuristic markers, never a root-cause claim. No match text is retained/logged.
    data = (stdout + b'\n' + stderr).lower()
    patterns = (
        ('storage-full-marker', rb'no space left on device|disk full'),
        ('process-killed-marker', rb'killed: 9|killed process|out of memory'),
        ('network-marker', rb'could not resolve host|connection timed out|network is unreachable|failed host lookup'),
        ('upload-duplicate-marker', rb'itms-90189|redundant binary upload|bundle version.*already.*used'),
        ('upload-auth-marker', rb'authentication failed|unable to authenticate|invalid issuer|invalid api key'),
        ('upload-validation-marker', rb'validation failed|asset validation failed|itms-90[0-9]{3}'),
        ('signing-marker', rb'no signing certificate|no profiles for|errsecinternalcomponent|mac verify error'),
        ('dart-compiler-marker', rb'error:.*(?:isn.t defined|is not defined|couldn.t resolve)|target kernel_snapshot.*failed'),
        ('native-compiler-marker', rb'fatal error:|clang: error:|swift compiler error|undefined symbols for architecture|ld:.*error'),
        ('dependency-marker', rb'version solving failed|could not find compatible versions|sandbox is not in sync'),
        ('export-marker', rb'error: exportarchive|export archive failed'),
    )
    return next((category for category, pattern in patterns if re.search(pattern, data)), 'tool-nonzero')


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
    try:
        result = subprocess.run(args, cwd=cwd, env=env, stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE, timeout=timeout, check=False)
    except subprocess.TimeoutExpired:
        raise ToolFailure('tool-timeout') from None
    except FileNotFoundError:
        raise ToolFailure('tool-missing') from None
    except OSError:
        raise ToolFailure('tool-start-failed') from None
    if result.returncode != 0:
        raise ToolFailure(classify_tool_failure(result.stdout, result.stderr)) from None
    return result.stdout if output else None


def sha256(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def guard():
    mark('guard/dispatch-inputs')
    require(os.environ.get('GITHUB_REPOSITORY') == 'mekidoapps/vending_navi')
    require(os.environ.get('GITHUB_REF') == 'refs/heads/ios/device-configuration')
    require(os.environ.get('ALLOWED_BRANCH') == 'ios/device-configuration')
    require(os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch')
    require(os.environ.get('GITHUB_RUN_ATTEMPT') == '1')
    require(os.environ.get('SERVICES_CONFIRMED') == 'true')
    expected = os.environ['EXPECTED_SHA']
    require(re.fullmatch(r'[0-9a-f]{40}', expected))
    require(expected == os.environ['GITHUB_SHA'])
    mark('guard/source-head')
    require(command(['git', 'rev-parse', 'HEAD'], output=True).decode().strip() == expected)
    require(re.fullmatch(r'[1-9][0-9]{0,8}', os.environ['BUILD_NUMBER']))
    mark('guard/lock-and-version')
    require(sha256(ROOT / 'ios/Podfile.lock') == LOCK_SHA256)
    require(re.search(r'^version: 1\.0\.0\+21\s*$', (ROOT / 'pubspec.yaml').read_text(), re.M))
    mark('guard/toolchain-path')
    require(os.environ['DEVELOPER_DIR'] == '/Applications/Xcode_26.3.app/Contents/Developer')
    require(Path(os.environ['DEVELOPER_DIR']).is_dir())
    mark('guard/xcode-version')
    require(b'Xcode 26.3' in command(['xcodebuild', '-version'], output=True))
    mark('guard/sdk-version')
    require(int(command(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'],
                        output=True).decode().split('.')[0]) >= 26)


def receipt_identity():
    return {'source': os.environ['EXPECTED_SHA'], 'build': os.environ['BUILD_NUMBER'],
            'run': os.environ['GITHUB_RUN_ID'], 'bundle': BUNDLE}


def validate_info(info):
    require(info.get('CFBundleIdentifier') == BUNDLE)
    require(info.get('CFBundleDisplayName') == '���̋@�i�r')
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
    mark('build/guard')
    guard()
    mark('build/workspace')
    target = work()
    require(not target.exists())
    target.mkdir(mode=0o700)
    services = ROOT / 'ios/Flutter/LocalServices.xcconfig'
    require(not services.exists())
    (target / 'services-owned').touch()
    mark('build/runtime-inputs')
    require(all(os.environ.get(name) for name in SERVICES))
    mark('build/write-runtime-settings')
    services.write_text(''.join(name + ' = ' + os.environ[name] + '\n' for name in SERVICES))
    try:
        mark('build/runtime-settings-check')
        command(['node', 'tool/check_ios_runtime_config.cjs'])
        mark('build/flutter-archive')
        command(['flutter', 'build', 'ipa', '--release', '--no-codesign', '--no-pub',
                 '--dart-define=APP_ENTRY=v2', '--build-name=1.0.0',
                 '--build-number=' + os.environ['BUILD_NUMBER']], timeout=1650)
        mark('build/locked-files-check')
        command(['git', 'diff', '--exit-code', '--', 'pubspec.yaml', 'pubspec.lock', 'ios/Podfile.lock'])
        mark('build/archive-path')
        archive = ROOT / 'build/ios/archive/Runner.xcarchive'
        app = archive / 'Products/Applications/Runner.app'
        mark('build/built-runtime-check')
        command(['node', 'tool/check_ios_runtime_config.cjs', '--built-plist', str(app / 'Info.plist')])
        mark('build/app-info-and-receipt')
        receipt = receipt_identity()
        receipt['services_sha256'] = validate_info(app_info(app))
        mark('build/package-archive')
        payload = target / 'payload'
        payload.mkdir()
        shutil.move(str(archive), str(payload / 'Runner.xcarchive'))
        (payload / 'receipt.json').write_text(json.dumps(receipt))
    finally:
        with cleanup_stage('build/remove-runtime-settings'):
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
    mark('seal/workspace')
    target = work()
    payload = target / 'payload'
    require(payload.is_dir())
    if kind == 'ipa':
        require(not (target / 'keychains.json').exists())
    plain = target / 'transfer.zip'
    mark('seal/package')
    command(['ditto', '-c', '-k', '--norsrc', '--keepParent', str(payload), str(plain)])
    directory = target / 'transfer'
    directory.mkdir(exist_ok=True)
    mark('seal/transfer-key')
    password, mac_key = transfer_keys()
    encrypted = directory / (kind + '.enc')
    try:
        mark('seal/encrypt')
        command(['openssl', 'enc', '-aes-256-cbc', '-pbkdf2', '-iter', '200000', '-salt',
                 '-in', str(plain), '-out', str(encrypted), '-pass', 'env:VN_TRANSFER_PASSWORD'],
                extra_env={'VN_TRANSFER_PASSWORD': password})
        mark('seal/authenticate')
        (directory / (kind + '.mac')).write_text(mac_file(encrypted, mac_key, kind))
    finally:
        with cleanup_stage('seal/remove-plaintext'):
            plain.unlink(missing_ok=True)
    mark('seal/remove-payload')
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
    mark('open/workspace')
    target = work()
    directory = target / 'transfer'
    mark('open/transfer-key')
    password, mac_key = transfer_keys()
    encrypted = directory / (kind + '.enc')
    mark('open/authenticate')
    require(hmac.compare_digest((directory / (kind + '.mac')).read_text(),
                                mac_file(encrypted, mac_key, kind)))
    plain = target / 'transfer.zip'
    require(not (target / 'payload').exists())
    try:
        mark('open/decrypt')
        command(['openssl', 'enc', '-d', '-aes-256-cbc', '-pbkdf2', '-iter', '200000',
                 '-in', str(encrypted), '-out', str(plain), '-pass', 'env:VN_TRANSFER_PASSWORD'],
                extra_env={'VN_TRANSFER_PASSWORD': password})
        mark('open/safe-extract')
        with zipfile.ZipFile(plain) as archive:
            extract_zip(archive, target)
        mark('open/receipt-identity')
        receipt = json.loads((target / 'payload/receipt.json').read_text())
        require(all(receipt.get(key) == value for key, value in receipt_identity().items()))
        mark('open/payload-integrity')
        if kind == 'archive':
            require(validate_info(app_info(target / 'payload/Runner.xcarchive/Products/Applications/Runner.app'))
                    == receipt['services_sha256'])
        else:
            require(sha256(target / 'payload/Runner.ipa') == receipt['ipa_sha256'])
    finally:
        with cleanup_stage('open/remove-plaintext'):
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
    phase = 'app-and-signature'
    mark(phase)
    try:
        apps = list((unpacked / 'Payload').glob('*.app'))
        require(len(apps) == 1)
        app = apps[0]
        require(validate_info(app_info(app)) == receipt['services_sha256'])
        command(['codesign', '--verify', '--deep', '--strict', str(app)])
        phase = 'embedded-profile-decode'
        mark(phase)
        profile = plistlib.loads(command(['security', 'cms', '-D', '-i',
                                         str(app / 'embedded.mobileprovision')], output=True))
        phase = 'embedded-profile-validation'
        mark(phase)
        validate_profile(profile, datetime.datetime.utcnow())
        phase = 'embedded-profile-uuid'
        mark(phase)
        require(expected_uuid is None or profile['UUID'] == expected_uuid)
        phase = 'entitlements-extract'
        mark(phase)
        ent_data = command(['codesign', '-d', '--entitlements', '-', '--xml', str(app)], output=True)
        phase = 'entitlements-parse'
        mark(phase)
        ent = plistlib.loads(ent_data)
        phase = 'entitlements-match'
        mark(phase)
        require(ent.get('application-identifier') == TEAM + '.' + BUNDLE)
        require(ent.get('com.apple.developer.team-identifier') == TEAM)
        require(ent.get('get-task-allow', False) is False)
        prefix = target / 'signer-cert'
        try:
            phase = 'certificate-extract'
            mark(phase)
            command(['codesign', '-d', '--extract-certificates=' + str(prefix), str(app)])
            phase = 'certificate-match'
            mark(phase)
            fingerprint = hashlib.sha1(Path(str(prefix) + '0').read_bytes()).hexdigest().upper()
            require(fingerprint in [hashlib.sha1(cert).hexdigest().upper()
                                    for cert in profile['DeveloperCertificates']])
            require(expected_fingerprint is None or fingerprint == expected_fingerprint)
        finally:
            with cleanup_stage('ipa/remove-certificates'):
                for certificate in target.glob('signer-cert*'):
                    certificate.unlink()
    except DiagnosticError:
        raise
    except Exception as error:
        raise SigningStageError('verify-exported-ipa/' + phase, error_category(error)) from None
    finally:
        with cleanup_stage('ipa/remove-unpacked'):
            shutil.rmtree(unpacked)


def sign():
    phase = 'guard-source-and-toolchain'
    mark(phase)
    try:
        guard()
        target = work()
        phase = 'validate-unsigned-archive'
        mark(phase)
        payload = target / 'payload'
        archive = payload / 'Runner.xcarchive'
        receipt = json.loads((payload / 'receipt.json').read_text())
        require(validate_info(app_info(archive / 'Products/Applications/Runner.app')) == receipt['services_sha256'])
        phase = 'decode-p12'
        mark(phase)
        decode('IOS_DISTRIBUTION_P12_BASE64', target / 'certificate.p12')
        phase = 'decode-profile'
        mark(phase)
        decode('IOS_APPSTORE_PROFILE_BASE64', target / 'profile.mobileprovision')
        phase = 'decode-profile-cms'
        mark(phase)
        profile = plistlib.loads(command(['security', 'cms', '-D', '-i',
                                         str(target / 'profile.mobileprovision')], output=True))
        phase = 'validate-appstore-profile'
        mark(phase)
        validate_profile(profile, datetime.datetime.utcnow())
        phase = 'prepare-temporary-keychain'
        mark(phase)
        keychain = target / 'signing.keychain-db'
        require(not keychain.exists() and not (target / 'keychains.json').exists())
        old = shlex.split(command(['security', 'list-keychains', '-d', 'user'], output=True).decode())
        (target / 'keychains.json').write_text(json.dumps(old))
        password = secrets.token_urlsafe(32)
        command(['security', 'create-keychain', '-p', password, str(keychain)])
        command(['security', 'set-keychain-settings', '-lut', '900', str(keychain)])
        command(['security', 'unlock-keychain', '-p', password, str(keychain)])
        phase = 'import-distribution-p12'
        mark(phase)
        command(['security', 'import', str(target / 'certificate.p12'), '-P',
                 os.environ['IOS_DISTRIBUTION_P12_PASSWORD'], '-k', str(keychain),
                 '-T', '/usr/bin/codesign'])
        (target / 'certificate.p12').unlink()
        phase = 'configure-keychain-access'
        mark(phase)
        command(['security', 'set-key-partition-list', '-S', 'apple-tool:,apple:',
                 '-s', '-k', password, str(keychain)])
        command(['security', 'list-keychains', '-d', 'user', '-s', str(keychain), *old])
        phase = 'find-valid-distribution-identity'
        mark(phase)
        identities = command(['security', 'find-identity', '-v', '-p', 'codesigning',
                              str(keychain)], output=True).decode()
        phase = 'match-profile-certificate'
        mark(phase)
        fingerprint = distribution_identity(profile, identities)
        phase = 'install-appstore-profile'
        mark(phase)
        uuid = profile['UUID']
        require(all(not (directory / (uuid + '.mobileprovision')).exists()
                    for directory in profile_directories()))
        (target / 'installed-profile.txt').write_text(uuid)
        for directory in profile_directories():
            directory.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(target / 'profile.mobileprovision', directory / (uuid + '.mobileprovision'))
        phase = 'prepare-export-options'
        mark(phase)
        options = {'method': 'app-store-connect', 'destination': 'export', 'teamID': TEAM,
                   'signingStyle': 'manual', 'signingCertificate': fingerprint,
                   'provisioningProfiles': {BUNDLE: PROFILE_NAME},
                   'manageAppVersionAndBuildNumber': False, 'uploadSymbols': False}
        with (target / 'ExportOptions.plist').open('wb') as stream:
            plistlib.dump(options, stream)
        # No Flutter, pod, Ruby, project build or provisioning update in this job.
        phase = 'xcode-export-archive'
        mark(phase)
        command(['xcodebuild', '-exportArchive', '-archivePath', str(archive),
                 '-exportPath', str(target / 'export'),
                 '-exportOptionsPlist', str(target / 'ExportOptions.plist')], timeout=600)
        phase = 'locate-exported-ipa'
        mark(phase)
        ipas = list((target / 'export').glob('*.ipa'))
        require(len(ipas) == 1)
        phase = 'verify-exported-ipa'
        mark(phase)
        verify_ipa(ipas[0], receipt, uuid, fingerprint)
        phase = 'record-verified-ipa'
        mark(phase)
        shutil.rmtree(archive)
        shutil.move(str(ipas[0]), str(payload / 'Runner.ipa'))
        receipt['ipa_sha256'] = sha256(payload / 'Runner.ipa')
        receipt['profile_uuid'] = uuid
        receipt['signing_sha1'] = fingerprint
        (payload / 'receipt.json').write_text(json.dumps(receipt))
    except (SigningStageError, DiagnosticError):
        raise
    except Exception as error:
        raise SigningStageError(phase, error_category(error)) from None
    finally:
        # Must succeed before any encrypted IPA artifact or upload job can proceed.
        try:
            cleanup_signing()
        except Exception:
            raise SigningStageError('cleanup-signing-material') from None


def upload():
    mark('upload/guard')
    guard()
    mark('upload/workspace')
    target = work()
    mark('upload/read-receipt')
    receipt = json.loads((target / 'payload/receipt.json').read_text())
    ipa = target / 'payload/Runner.ipa'
    mark('upload/ipa-digest')
    require(sha256(ipa) == receipt['ipa_sha256'])
    mark('upload/verify-ipa')
    verify_ipa(ipa, receipt, receipt['profile_uuid'], receipt['signing_sha1'])
    mark('upload/api-identifiers')
    key_id = os.environ['ASC_API_KEY_ID']
    issuer = os.environ['ASC_API_ISSUER_ID']
    require(re.fullmatch(r'[A-Z0-9]{10}', key_id))
    require(re.fullmatch(r'[0-9A-Fa-f]{8}(-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', issuer))
    mark('upload/key-directory')
    keys = target / 'private_keys'
    require(not keys.exists())
    keys.mkdir(mode=0o700)
    try:
        key = keys / ('AuthKey_' + key_id + '.p8')
        mark('upload/decode-api-key')
        decode('ASC_API_KEY_P8_BASE64', key)
        mark('upload/validate-api-key')
        command(['openssl', 'pkey', '-in', str(key), '-check', '-noout'])
        mark('upload/apple-submit-once')
        command(['xcrun', 'altool', '--upload-app', '--type', 'ios', '--file', str(ipa),
                 '--apiKey', key_id, '--apiIssuer', issuer], cwd=target, timeout=480)
        mark('upload/accepted-summary')
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as summary:
            summary.write('Apple upload command accepted; processing/tester availability unverified.\n'
                          + 'Source: ' + os.environ['EXPECTED_SHA'] + '\n'
                          + 'Version: 1.0.0 (' + os.environ['BUILD_NUMBER'] + '); APP_ENTRY=v2\n')
    finally:
        with cleanup_stage('upload/remove-api-key'):
            shutil.rmtree(keys)


def cleanup():
    mark('cleanup/workspace')
    target = work()
    if not target.exists():
        return
    mark('cleanup/signing')
    cleanup_signing()
    mark('cleanup/runtime-settings')
    if (target / 'services-owned').exists():
        (ROOT / 'ios/Flutter/LocalServices.xcconfig').unlink(missing_ok=True)
    mark('cleanup/workspace-material')
    shutil.rmtree(target)
    mark('cleanup/build-material')
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
        mark('entry')
        commands[mode]()
    except BaseException as error:
        stage = str(error) if isinstance(error, SigningStageError) else getattr(error, 'stage', CURRENT_STAGE)
        failure = DiagnosticError(stage, error_category(error))
        if mode != 'guard':
            try:
                cleanup()
            except BaseException as cleanup_error:
                raise DiagnosticError(CURRENT_STAGE, error_category(cleanup_error)) from None
        raise failure from None


if __name__ == '__main__':
    try:
        main()
    except DiagnosticError as error:
        print('TestFlight failed at fixed stage: ' + error.stage + '; category: ' + error.category + '. Values and tool output withheld.', file=sys.stderr)
        sys.exit(1)
    except SigningStageError as error:
        print('TestFlight signing failed at fixed stage: ' + (str(error) if str(error) in DIAGNOSTIC_STAGES else 'entry') + '. Values and tool output withheld.', file=sys.stderr)
        sys.exit(1)
    except BaseException:
        print('TestFlight stage failed or was interrupted; tool output and values withheld.', file=sys.stderr)
        sys.exit(1)
