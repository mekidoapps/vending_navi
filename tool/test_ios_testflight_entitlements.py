"""Offline synthetic-profile/IPA tests; no signing material or native tools."""
import contextlib
import copy
import datetime
import hashlib
import io
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import ios_testflight as release

APPLE = 'com.apple.developer.applesignin'
INVALID = (None, [], 'Default', ['default'], ['Other'], ['Default', 'Other'],
           ['Default', 'Default'], {'Default': True}, True)


class AppleEntitlementTests(unittest.TestCase):
    def setUp(self):
        self.now = datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)
        self.profile = {
            'Name': release.PROFILE_NAME,
            'TeamIdentifier': [release.TEAM],
            'ApplicationIdentifierPrefix': [release.TEAM],
            'CreationDate': self.now - datetime.timedelta(days=1),
            'ExpirationDate': self.now + datetime.timedelta(days=30),
            'UUID': '12345678-1234-1234-1234-123456789abc',
            'DeveloperCertificates': [b'synthetic-public-certificate'],
            'Entitlements': {
                'application-identifier': release.TEAM + '.' + release.BUNDLE,
                'com.apple.developer.team-identifier': release.TEAM,
                'get-task-allow': False,
                'beta-reports-active': True,
                APPLE: ['Default'],
            },
        }

    def test_profile_accepts_exact_default(self):
        release.validate_profile(self.profile, self.now)

    def test_profile_rejects_missing_or_invalid_without_disclosing_values(self):
        for value in INVALID:
            with self.subTest(value=value):
                profile = copy.deepcopy(self.profile)
                if value is None:
                    profile['Entitlements'].pop(APPLE)
                else:
                    profile['Entitlements'][APPLE] = value
                with self.assertRaisesRegex(ValueError, '^Release prerequisite failed$'):
                    release.validate_profile(profile, self.now)

    def verify_synthetic_ipa(self, *, signed_value=['Default'], profile_value=['Default'], expected_stage=None):
        profile = copy.deepcopy(self.profile)
        if profile_value is None:
            profile['Entitlements'].pop(APPLE)
        else:
            profile['Entitlements'][APPLE] = profile_value
        signed = copy.deepcopy(self.profile['Entitlements'])
        if signed_value is None:
            signed.pop(APPLE)
        else:
            signed[APPLE] = signed_value
        calls = []
        with tempfile.TemporaryDirectory(prefix='synthetic-ipa-') as directory:
            target = Path(directory)
            ipa = target / 'synthetic.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('Payload/Runner.app/Info.plist', plistlib.dumps({}))

            def command(args, **kwargs):
                calls.append(args)
                if args[:2] == ['security', 'cms']:
                    return plistlib.dumps(profile)
                if '--entitlements' in args:
                    return plistlib.dumps(signed)
                if any(argument.startswith('--extract-certificates=') for argument in args):
                    (target / 'signer-cert0').write_bytes(b'synthetic-public-certificate')
                return b''

            output = io.StringIO()
            with patch.object(release, 'work', return_value=target), \
                 patch.object(release, 'app_info', return_value={}), \
                 patch.object(release, 'validate_info', return_value='synthetic-services'), \
                 patch.object(release, 'command', side_effect=command), \
                 contextlib.redirect_stderr(output), contextlib.redirect_stdout(output):
                if expected_stage:
                    with self.assertRaises(release.SigningStageError) as raised:
                        release.verify_ipa(ipa, {'services_sha256': 'synthetic-services'})
                    self.assertEqual(str(raised.exception), expected_stage)
                    self.assertEqual(raised.exception.category, 'validation')
                else:
                    release.verify_ipa(ipa, {'services_sha256': 'synthetic-services'},
                                       expected_uuid=self.profile['UUID'],
                                       expected_fingerprint=hashlib.sha1(b'synthetic-public-certificate').hexdigest().upper())
            self.assertFalse((target / 'verified-ipa').exists(), 'IPA unpack cleanup must run')
            self.assertFalse(list(target.glob('signer-cert*')), 'certificate cleanup must run')
            self.assertNotIn(APPLE, output.getvalue())
            self.assertNotIn('Default', output.getvalue())
            self.assertNotIn(self.profile['UUID'], output.getvalue())
            self.assertNotIn('synthetic-public-certificate', output.getvalue())
            self.assertNotIn('Other', output.getvalue())
            if expected_stage:
                self.assertFalse(any(any(argument.startswith('--extract-certificates=') for argument in args) for args in calls))

    def test_exported_ipa_accepts_exact_default_in_both(self):
        self.verify_synthetic_ipa()

    def test_exported_ipa_rejects_missing_or_invalid_signed_entitlement(self):
        for value in INVALID:
            with self.subTest(value=value):
                self.verify_synthetic_ipa(signed_value=value,
                                          expected_stage='verify-exported-ipa/entitlements-match')

    def test_exported_ipa_rejects_missing_or_invalid_embedded_profile(self):
        for value in INVALID:
            with self.subTest(value=value):
                self.verify_synthetic_ipa(profile_value=value,
                                          expected_stage='verify-exported-ipa/embedded-profile-validation')


if __name__ == '__main__':
    unittest.main()
