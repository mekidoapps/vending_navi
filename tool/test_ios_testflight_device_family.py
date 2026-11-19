"""Offline regression checks. Synthetic plists only; no signing/network commands."""
from contextlib import ExitStack
import copy
import hashlib
import json
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest import mock
import zipfile

import ios_testflight as candidate


def valid_info():
    return {
        'CFBundleIdentifier': candidate.BUNDLE,
        'CFBundleDisplayName': '自販機ナビ',
        'CFBundleShortVersionString': '1.0.0',
        'CFBundleVersion': '26',
        'UIDeviceFamily': [1],
        'GoogleMapsAPIKey': 'AIza' + 'A' * 35,
        'GIDClientID': 'unit-test.apps.googleusercontent.com',
        'CFBundleURLTypes': [
            {'CFBundleURLSchemes': ['com.googleusercontent.apps.unit-test']}],
    }


class IphoneFamilyGateTests(unittest.TestCase):
    def setUp(self):
        self.env = mock.patch.dict(os.environ, {'BUILD_NUMBER': '26'}, clear=True)
        self.env.start()
        self.addCleanup(self.env.stop)

    def test_mixed_family_rejected(self):
        info = valid_info()
        info['UIDeviceFamily'] = [1, 2]
        with self.assertRaises(ValueError):
            candidate.validate_info(info)

    def test_exact_iphone_family_preserves_service_digest(self):
        info = valid_info()
        expected = hashlib.sha256(json.dumps([
            info['GoogleMapsAPIKey'], info['GIDClientID'],
            ['com.googleusercontent.apps.unit-test'],
        ], sort_keys=True).encode()).hexdigest()
        self.assertEqual(candidate.validate_info(info), expected)

    def test_invalid_families_are_rejected(self):
        missing = object()
        invalid = [missing, None, [], [2], [1, 2], [2, 1], [1, 1],
                   1, '1', ['1'], [True], [1.0], (1,)]
        for family in invalid:
            with self.subTest(family='missing' if family is missing else family):
                info = valid_info()
                if family is missing:
                    del info['UIDeviceFamily']
                else:
                    info['UIDeviceFamily'] = family
                with self.assertRaises(ValueError):
                    candidate.validate_info(info)

    def test_binary_plist_roundtrip(self):
        for family, accepted in (([1], True), ([1, 2], False), ([True], False)):
            with self.subTest(family=family):
                info = valid_info()
                info['UIDeviceFamily'] = family
                parsed = plistlib.loads(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
                if accepted:
                    self.assertEqual(candidate.validate_info(parsed),
                                     candidate.validate_info(valid_info()))
                else:
                    with self.assertRaises(ValueError):
                        candidate.validate_info(parsed)

    def test_existing_identity_and_runtime_checks_remain(self):
        invalid = {
            'CFBundleIdentifier': 'invalid.bundle',
            'CFBundleDisplayName': 'Wrong name',
            'CFBundleShortVersionString': '9.9.9',
            'CFBundleVersion': '25',
            'GoogleMapsAPIKey': 'not-a-key',
            'GIDClientID': 'invalid-client',
            'CFBundleURLTypes': [],
        }
        for key, value in invalid.items():
            with self.subTest(key=key):
                info = copy.deepcopy(valid_info())
                info[key] = value
                with self.assertRaises(ValueError):
                    candidate.validate_info(info)

    def test_sign_rejects_before_decoding_signing_material(self):
        with tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
            target = Path(directory)
            app = target / 'payload/Runner.xcarchive/Products/Applications/Runner.app'
            app.mkdir(parents=True)
            info = valid_info()
            info['UIDeviceFamily'] = [1, 2]
            (app / 'Info.plist').write_bytes(plistlib.dumps(info))
            receipt = {'services_sha256': candidate.validate_info(valid_info())}
            (target / 'payload/receipt.json').write_text(json.dumps(receipt))
            stack.enter_context(mock.patch.object(candidate, 'guard'))
            stack.enter_context(mock.patch.object(candidate, 'work', return_value=target))
            stack.enter_context(mock.patch.object(candidate, 'mark'))
            cleanup = stack.enter_context(mock.patch.object(candidate, 'cleanup_signing'))
            decode = stack.enter_context(mock.patch.object(candidate, 'decode'))
            command = stack.enter_context(mock.patch.object(candidate, 'command'))
            with self.assertRaises(candidate.SigningStageError) as caught:
                candidate.sign()
            self.assertEqual(str(caught.exception), 'validate-unsigned-archive')
            self.assertEqual(caught.exception.category, 'validation')
            decode.assert_not_called()
            command.assert_not_called()
            cleanup.assert_called_once_with()

    def test_upload_rejects_real_zip_before_codesign_or_api_key(self):
        with tempfile.TemporaryDirectory() as directory, ExitStack() as stack:
            target = Path(directory)
            (target / 'payload').mkdir()
            info = valid_info()
            info['UIDeviceFamily'] = [1, 2]
            ipa = target / 'payload/Runner.ipa'
            with zipfile.ZipFile(ipa, 'w') as archive:
                archive.writestr('Payload/Runner.app/Info.plist',
                                 plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
            receipt = {
                'services_sha256': candidate.validate_info(valid_info()),
                'ipa_sha256': candidate.sha256(ipa),
                'profile_uuid': 'synthetic-unused',
                'signing_sha1': 'synthetic-unused',
            }
            (target / 'payload/receipt.json').write_text(json.dumps(receipt))
            stack.enter_context(mock.patch.object(candidate, 'guard'))
            stack.enter_context(mock.patch.object(candidate, 'work', return_value=target))
            stack.enter_context(mock.patch.object(candidate, 'mark'))
            decode = stack.enter_context(mock.patch.object(candidate, 'decode'))
            command = stack.enter_context(mock.patch.object(candidate, 'command'))
            with self.assertRaises(candidate.SigningStageError) as caught:
                candidate.upload()
            self.assertEqual(str(caught.exception), 'verify-exported-ipa/app-and-signature')
            self.assertEqual(caught.exception.category, 'validation')
            decode.assert_not_called()
            command.assert_not_called()
            self.assertFalse((target / 'private_keys').exists())
            self.assertFalse((target / 'verified-ipa').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
