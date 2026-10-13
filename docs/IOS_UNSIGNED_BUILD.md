# iOS unsigned compile preparation

This is a compile check, not an installable iPhone build or distribution pipeline.
No Apple account, signing certificate, provisioning profile or GitHub Secret is
required. The workflow never launches the app, deploys Firebase, builds Android,
uploads an app artifact, or publishes to TestFlight/App Store.

## Source decision (2026-10-14 investigation)

- Remote: `https://github.com/mekidoapps/vending_navi`, default `main`.
- `main`: `f9a29334301e82043722dfaca219849f01c7545e`, version `1.0.0+11`.
- `develop-v2`: `3f40869355a82c5a1a6d617bd9a15b0db327fa1f`.
  Version `1.0.0+21`, 160 commits ahead
  of `main`, with no main-only commits. Preparation branch:
  `prep/ios-unsigned-build`, based on this remote branch.
- RC21 Android immutable AAB source:
  `0904f42309082877bd8137adeb6903dfd6b2ef15`; `APP_ENTRY=v2`; Flutter 3.41.2.
  The branch tip includes later OSM tooling/rules and documentation. Application
  Dart/iOS files have no changes between that source and the inspected tip.
- GitHub Releases API returned `[]`; phase tags are not a current production
  release. `docs/releases/v1.0.0+21_RC.md` still records Alpha active and
  Production authorization pending. Reconcile this with the user's later
  Production 1.0.0(21) information before choosing a release source. Do not
  treat this inspection as evidence of the current Play Console state.
- No preexisting checkout was found in this task workspace/Documents/Codex;
  the old `C:/Users/domek/vending_app` is absent. A separate clone was used.
  No `.agents/skills` or existing `.github` workflows are tracked at this tip.
  Root `AGENTS.md` was read; known memory_summary.md locations were absent.

## Compile configuration

- Manual `workflow_dispatch` only; read-only repository permission; no stored
  checkout credentials; action dependencies pinned to reviewed tag SHAs.
- `macos-15`, explicitly Xcode 26.3, iPhone SDK major >=26; fail if removed
  from the runner image. Flutter 3.41.2 is pinned to the Android release evidence.
- Exact selected-branch SHA must match the `expected_sha` input. Version guard
  rejects old main. Flutter pub resolution must preserve `pubspec.lock`.
- `flutter build ios --release --no-codesign --dart-define=APP_ENTRY=v2`.
- Added CocoaPods Podfile and Pods xcconfig includes. Runner deployment minimum
  raised from 13 to 14 because locked `google_maps_flutter_ios` 2.18.1 requires
  iOS 14. CocoaPods selects compatible native Maps versions for this minimum.
  No Dart package upgrades. Minimum may need reconsideration after native
  resolution, not a silent upgrade in CI.
- No Podfile.lock exists yet: first native resolution is not fully reproducible.
  After an approved successful macOS run, obtain/review its Podfile.lock on a
  Mac and commit it before using this for release validation.
- Only safe source/toolchain evidence and Podfile.lock checksum go into the
  run summary. Do not upload binaries, plist configs or verbose environment logs.

## Before an approved first run

1. Confirm `develop-v2` is the intended source and reconcile any newer unpushed
   work on the other PC. Review the complete diff; this preparation adds no
   credentials or new client keys and is suitable for public review.
2. Separately authorize pushing the preparation branch. To enable manual runs,
   separately review/merge **only the workflow file** into default `main` (or
   agree a default-branch strategy). Do not merge all develop-v2 merely to
   register the workflow, and do not compile old main.
3. Check the current macos-15 image still has Xcode_26.3 and SDK >=26, repository
   Actions are enabled, and pinned actions are allowed by repository policy.
   Standard hosted runners for public repos are free; do not select larger or
   paid runners. No billing or permission changes are part of these steps.
4. After separate execution approval, select `prep/ios-unsigned-build` in Actions
   > iOS unsigned compile > Run workflow. Enter its final complete commit SHA
   (after committing preparation), not the base SHA, as `expected_sha`.
5. Review compile result and source/toolchain summary. Failure may expose a
   native dependency/toolchain incompatibility: inspect before changing locks.
   A success proves compile only; no runtime integration or signing is tested.

## Runtime and later distribution gaps

- Firebase Dart iOS options and bundle ID `com.mekidoapps.vendingnavi` exist;
  ignored `ios/Runner/GoogleService-Info.plist` is absent. Do not regenerate or
  change cloud registrations. Verify the existing iOS registration and obtain
  the matching config through an authorized separate setup.
- AppDelegate lacks Google Maps SDK API-key initialization. Google Sign-In
  lacks the iOS client/URL-scheme configuration. Confirm matching OAuth client
  and restricted iOS Maps key without reusing/modifying Android keys.
- Info.plist has location-when-in-use text but no camera/photo-library usage
  descriptions. Photo workflows, login, Maps, location and notification paths
  require separate iOS setup and real-device smoke testing.
- Release bootstrap uses Apple DeviceCheck App Check. Verify iOS App Check
  registration/provider and required Apple credentials later; do not weaken
  enforcement or activate debug provider for release.
- Confirm Apple Developer Program membership, bundle ID ownership, signing
  team/profiles, privacy manifests/disclosures, icons/display name, and review
  requirements before preparing TestFlight/App Store distribution. A signed
  build is required for normal iPhone installation; unsigned Runner.app is
  not a user-installable deliverable.

## Verification boundary and official references

Windows has no Flutter/Xcode/CocoaPods toolchain on PATH. Local checks cover
Git diff whitespace, workflow static validation, plist XML and Bash syntax.
Completed checks: `actionlint 1.7.12 -shellcheck=` (PASS, no ShellCheck installed),
`bash -n` on extracted multiline workflow commands (PASS), `git diff --check`
(PASS), PowerShell XML parsing of both existing plists (PASS), all three Runner
deployment targets equal 14.0 (PASS), and `git diff --quiet` of RC21 source versus
develop-v2 for `lib ios pubspec.yaml pubspec.lock` (PASS).
Pod resolution, Ruby execution, Flutter analyze/tests and iOS compilation have
not been run. No push, Actions run, Secrets, certificates, Apple registration,
cloud writes, permission changes or payment occurred.

- [Apple upload requirements](https://developer.apple.com/news/upcoming-requirements/):
  Xcode 26+/iOS 26+ SDK since April 28, 2026; target iOS 13+ since September 9,
  2026. The preparation uses minimum iOS 14 and Xcode 26.3.
- [Runner image](https://github.com/actions/runner-images/blob/main/images/macos/macos-15-Readme.md)
- [Manual workflow default-branch requirement](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
- [Public runner billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
