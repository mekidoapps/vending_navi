"""Offline only: synthetic metadata and mocked native/network boundaries."""

import hashlib
import json
import plistlib
import struct
import tempfile
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

import capture_driver as driver


class LargeCaptureTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.app = self.root / 'app'
        self.work = self.root / 'work'
        self.work.mkdir()
        self.enterContext(patch.object(driver, 'safe_print'))
        self.enterContext(patch.object(driver, 'EVENTS', []))
        self.enterContext(patch.object(
            driver, 'DIAGNOSTIC_ROOT', self.work / 'diagnostics',
        ))
        self.enterContext(patch.object(driver, 'DEADLINE_START', None))
        self.enterContext(patch.object(
            driver.urllib.request,
            'build_opener',
            side_effect=AssertionError('no network'),
        ))
        self.enterContext(patch.object(
            driver.subprocess,
            'Popen',
            side_effect=AssertionError('no process'),
        ))

    def info(self):
        return {
            'CFBundleIdentifier': driver.BUNDLE,
            'CFBundleShortVersionString': '1.0.0',
            'CFBundleVersion': driver.BUILD_NUMBER,
            'CFBundleSupportedPlatforms': ['iPhoneSimulator'],
            'UIDeviceFamily': [1],
        }

    def fixture(self):
        product = self.app / 'build/ios/iphonesimulator/Runner.app'
        product.mkdir(parents=True)
        (product / 'Info.plist').write_bytes(plistlib.dumps(self.info()))
        driver.save_state(self.work, {'devices': ['synthetic-device']})

    def simulate(
        self,
        size=(1320, 2868),
        ready=True,
        healthy=True,
        fail_boot=False,
    ):
        self.fixture()
        diagnostics = MagicMock()
        diagnostics.wait_ready.return_value = ready
        diagnostics.healthy.return_value = healthy
        diagnostics.stop.return_value = True

        def command(args, **kwargs):
            if fail_boot and args[2] == 'boot':
                raise driver.CommandFailure(1)
            if 'screenshot' in args:
                header = b'\x89PNG\r\n\x1a\n' + b'\0' * 8
                Path(args[-1]).write_bytes(header + struct.pack('>II', *size))
            return b''

        environment = {
            'APP_CHECK_DEBUG_TOKEN': '00000000-0000-0000-0000-000000000000',
        }
        with (
            patch.dict(driver.os.environ, environment, clear=True),
            patch.object(driver, 'command', side_effect=command) as mock,
            patch.object(driver, 'AppDiagnostics', return_value=diagnostics),
        ):
            try:
                driver.capture(self.app, self.work)
            finally:
                self.commands = mock.call_args_list
                self.diagnostics = diagnostics

    def test_target_is_exact_single_large_phone(self):
        self.assertEqual(driver.TARGETS, [
            ('iphone-dynamic-large', 'iPhone 16 Pro Max', {(1320, 2868)}),
        ])

    def test_large_capture_receipt_and_filename(self):
        self.simulate()
        receipt_path = self.work / 'output/receipt.json'
        receipt = json.loads(receipt_path.read_text())[0]
        self.assertEqual(
            (receipt['device'], receipt['width'], receipt['height']),
            ('iPhone 16 Pro Max', 1320, 2868),
        )
        self.assertEqual(
            {path.name for path in (self.work / 'output').iterdir()},
            {'iphone-dynamic-large.png', 'receipt.json'},
        )
        self.assertIn('PENDING', receipt['visual_review'])

    def test_medium_dimensions_rejected(self):
        with self.assertRaises(RuntimeError):
            self.simulate((1179, 2556))
        self.assertFalse((self.work / 'output/receipt.json').exists())
        self.diagnostics.stop.assert_called()

    def test_alternate_large_dimensions_not_silently_accepted(self):
        with self.assertRaises(RuntimeError):
            self.simulate((1290, 2796))
        self.assertFalse((self.work / 'output/receipt.json').exists())

    def test_readiness_failure_does_not_capture(self):
        with self.assertRaises(RuntimeError):
            self.simulate(ready=False)
        self.assertFalse(any(
            'screenshot' in call.args[0] for call in self.commands
        ))
        self.diagnostics.stop.assert_called()

    def test_error_during_capture_does_not_make_receipt(self):
        with self.assertRaises(RuntimeError):
            self.simulate(healthy=False)
        self.assertFalse((self.work / 'output/receipt.json').exists())
        self.diagnostics.stop.assert_called()

    def test_boot_failure_stops_before_install(self):
        with self.assertRaises(driver.CommandFailure):
            self.simulate(fail_boot=True)
        self.assertFalse(any(
            'install' in call.args[0] for call in self.commands
        ))
        self.diagnostics.stop.assert_called()

    def test_large_diagnostic_roundtrip_and_closed_vocabulary(self):
        with driver.stage('iphone-dynamic-large', 'boot'):
            pass
        driver.EVENTS.clear()
        driver.restore_diagnostics()
        self.assertEqual(len(driver.EVENTS), 1)
        with self.assertRaises(RuntimeError):
            with driver.stage('iphone-dynamic-medium', 'boot'):
                pass

    def test_cleanup_shuts_down_owned_large_device(self):
        driver.save_state(self.work, {'devices': ['synthetic-device']})
        states = iter(['Booted', 'Shutdown'])

        def command(args, **kwargs):
            if args[2:4] == ['list', 'devices']:
                devices = {'runtime': [{
                    'udid': 'synthetic-device',
                    'state': next(states),
                }]}
                return json.dumps({'devices': devices}).encode()
            return b''

        with patch.object(driver, 'command', side_effect=command) as mock:
            driver.cleanup(self.app, self.work)
        self.assertTrue(any(
            call.args[0][2:] == ['shutdown', 'synthetic-device']
            for call in mock.call_args_list
        ))

    def test_preflight_only_exact_available_shutdown_device(self):
        files = {
            'lib/core/errors/capture_diagnostics.dart': '[CAPTURE_DIAGNOSTIC]',
            'ios/Podfile.lock': 'synthetic-lock',
            'ios/Runner.xcodeproj/project.pbxproj': (
                'TARGETED_DEVICE_FAMILY = 1;\n' * 3
            ),
            'pubspec.yaml': 'version: 1.0.0+21\n',
            'lib/firebase_options.dart': driver.APP_ID + ' vendingnavi',
        }
        for name, data in files.items():
            path = self.app / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(data)

        cases = [
            ('iPhone 16 Pro Max', True, 'Shutdown', True),
            ('iPhone 16', True, 'Shutdown', False),
            ('iPhone 16 Pro Max', False, 'Shutdown', False),
            ('iPhone 16 Pro Max', True, 'Booted', False),
        ]
        lock_hash = hashlib.sha256(b'synthetic-lock').hexdigest()
        for name, available, state, allowed in cases:
            device = {
                'name': name,
                'isAvailable': available,
                'state': state,
                'udid': 'synthetic',
            }
            inventory = {'devices': {driver.RUNTIME: [device]}}
            responses = [
                driver.SOURCE.encode(), json.dumps(inventory).encode(),
            ]
            with (
                self.subTest(device=device),
                patch.object(driver.sys, 'platform', 'darwin'),
                patch.object(driver, 'LOCK', lock_hash),
                patch.object(driver, 'command', side_effect=responses),
            ):
                if allowed:
                    driver.preflight(self.app, self.work)
                else:
                    with self.assertRaises(RuntimeError):
                        driver.preflight(self.app, self.work)


if __name__ == '__main__':
    unittest.main()
