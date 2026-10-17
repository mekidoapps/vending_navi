"""Synthetic seed/build contracts; does not run codesign or Xcode."""
import contextlib
import io
import os
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

import ios_testflight as release

REQUESTED = {'com.apple.developer.applesignin': ['Default']}


class SeedEntitlementsTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='synthetic-seed-')
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.source = self.root / 'ios/Runner/Runner.entitlements'
        self.source.parent.mkdir(parents=True)
        self.source.write_bytes(plistlib.dumps(REQUESTED))
        self.app = self.root / 'Runner.app'
        self.app.mkdir()
        self.output = io.StringIO()
        self.enterContext(contextlib.redirect_stdout(self.output))
        self.enterContext(contextlib.redirect_stderr(self.output))
        self.enterContext(patch.object(release, 'ROOT', self.root))

    def test_seed_uses_only_main_app_adhoc_identity_and_reviewed_source(self):
        with patch.object(release, 'command', return_value=plistlib.dumps(REQUESTED)) as command:
            release.seed_archive_entitlements(self.app)
        calls = command.call_args_list
        self.assertEqual(calls[0].args[0], [
            'codesign', '--force', '--sign', '-', '--timestamp=none',
            '--generate-entitlement-der', '--entitlements', str(self.source), str(self.app)])
        self.assertEqual(calls[1].args[0], ['codesign', '--verify', '--strict', str(self.app)])
        self.assertEqual(calls[2].args[0], ['codesign', '-d', '--entitlements', '-', '--xml', str(self.app)])
        for call in calls:
            self.assertNotIn('--deep', call.args[0])
            self.assertNotIn('extra_env', call.kwargs)
            self.assertLessEqual(call.kwargs['timeout'], 60)
        self.assertNotIn('Default', self.output.getvalue())

    def test_invalid_source_stops_before_any_native_tool(self):
        for source in ({}, {'com.apple.developer.applesignin': 'Default'},
                       {'com.apple.developer.applesignin': ['Other']},
                       {**REQUESTED, 'get-task-allow': True}, [], b'invalid-plist'):
            with self.subTest(source=source):
                self.source.write_bytes(source if isinstance(source, bytes) else plistlib.dumps(source))
                with patch.object(release, 'command') as command:
                    with self.assertRaises((ValueError, plistlib.InvalidFileException)):
                        release.seed_archive_entitlements(self.app)
                    command.assert_not_called()
                self.assertEqual(release.CURRENT_STAGE, 'build/seed-entitlements-source')

    def test_missing_modified_or_extra_seed_entitlement_is_rejected(self):
        for actual in ({}, {'com.apple.developer.applesignin': 'Default'},
                       {'com.apple.developer.applesignin': ['Other']},
                       {**REQUESTED, 'get-task-allow': True}, [], b'invalid-plist'):
            with self.subTest(actual=actual):
                data = actual if isinstance(actual, bytes) else plistlib.dumps(actual)
                with patch.object(release, 'command', side_effect=[b'', b'', data]):
                    with self.assertRaises((ValueError, plistlib.InvalidFileException)):
                        release.seed_archive_entitlements(self.app)
                self.assertEqual(release.CURRENT_STAGE, 'build/verify-seed-entitlements')
        self.assertNotIn('Other', self.output.getvalue())

    def test_each_native_seed_failure_stops_without_fallback(self):
        stages = ('build/seed-adhoc-signature', 'build/verify-seed-signature',
                  'build/verify-seed-entitlements')
        for index, stage in enumerate(stages):
            with self.subTest(stage=stage):
                with patch.object(release, 'command', side_effect=[b''] * index + [release.ToolFailure('tool-nonzero')]) as command:
                    with self.assertRaises(release.ToolFailure):
                        release.seed_archive_entitlements(self.app)
                    self.assertEqual(command.call_count, index + 1)
                    self.assertEqual(release.CURRENT_STAGE, stage)

    def run_synthetic_build(self, fail_seed=False):
        target = self.root / 'work'
        flutter_dir = self.root / 'ios/Flutter'
        flutter_dir.mkdir()
        archive = self.root / 'build/ios/archive/Runner.xcarchive'
        events = []
        def command(args, **kwargs):
            if args[:3] == ['flutter', 'build', 'ipa']:
                app = archive / 'Products/Applications/Runner.app'
                app.mkdir(parents=True)
                (app / 'Info.plist').write_bytes(plistlib.dumps({}))
                events.append('archive')
            return b''
        def seed(app):
            self.assertTrue(app.is_dir())
            self.assertFalse((target / 'payload').exists())
            events.append('seed')
            release.mark('build/verify-seed-entitlements')
            if fail_seed:
                raise ValueError('synthetic-failure-must-not-leak')
        with patch.object(release, 'work', return_value=target), \
             patch.object(release, 'guard'), \
             patch.object(release, 'command', side_effect=command), \
             patch.object(release, 'seed_archive_entitlements', side_effect=seed), \
             patch.object(release, 'validate_info', return_value='synthetic-services'), \
             patch.object(release, 'receipt_identity', return_value={'source': 'synthetic-source'}), \
             patch.dict(os.environ, {**{name: 'synthetic-runtime' for name in release.SERVICES}, 'BUILD_NUMBER': '42'}):
            if fail_seed:
                with self.assertRaisesRegex(ValueError, 'synthetic-failure'):
                    release.build()
            else:
                release.build()
        self.assertEqual(events, ['archive', 'seed'])
        self.assertFalse((flutter_dir / 'LocalServices.xcconfig').exists())
        self.assertEqual((target / 'payload/receipt.json').exists(), not fail_seed)
        self.assertEqual((target / 'payload/Runner.xcarchive').exists(), not fail_seed)
        return target

    def test_seed_precedes_archive_packaging_and_transfer(self):
        self.run_synthetic_build()

    def test_seed_failure_keeps_archive_unpublished_and_cleans_runtime_settings(self):
        self.run_synthetic_build(fail_seed=True)

    def test_main_failure_cleans_workspace_and_hides_values(self):
        def fail_seed():
            release.mark('build/verify-seed-entitlements')
            raise ValueError('synthetic-failure-must-not-leak')
        with patch.object(release.sys, 'argv', ['ios_testflight.py', 'build']), \
             patch.object(release.signal, 'signal'), \
             patch.object(release.os, 'umask'), \
             patch.object(release, 'build', side_effect=fail_seed), \
             patch.object(release, 'cleanup') as cleanup:
            with self.assertRaises(release.DiagnosticError) as raised:
                release.main()
            self.assertEqual(raised.exception.stage, 'build/verify-seed-entitlements')
            self.assertEqual(raised.exception.category, 'validation')
            cleanup.assert_called_once()
        self.assertNotIn('synthetic-failure-must-not-leak', self.output.getvalue())

    def test_child_processes_never_inherit_signing_credentials(self):
        with patch.dict(os.environ, {
            'PATH': 'synthetic-path', 'IOS_DISTRIBUTION_P12_BASE64': 'synthetic-secret',
            'IOS_DISTRIBUTION_P12_PASSWORD': 'synthetic-secret',
            'ASC_API_KEY_P8_BASE64': 'synthetic-secret', 'GITHUB_TOKEN': 'synthetic-secret',
        }, clear=True):
            self.assertEqual(release.child_environment(), {'PATH': 'synthetic-path'})


if __name__ == '__main__':
    unittest.main()
