# Phase A: release identity and Firebase configuration remediation

## Scope

Phase A addresses release-source traceability and canonical Firebase resource
selection. It does not change production data or deploy Firebase resources.

## Recovered source inventory

| Item | State at Phase A start |
|---|---|
| Local/GitHub branch | `develop-v2` |
| HEAD | `b67a8ae27bb252e231f438acb6afe35ef24d142b` |
| App version | `1.0.0+17` |
| Working tree | Clean |
| Functions source | Six production Callables plus emulator health |
| Functions tests | 137 passed |
| Master fixture | manufacturers 7 / products 96 / presets 33 |
| Existing release tag | Phase 5 tags only |
| v17 AAB/source manifest | Missing |

## Changes

- Use GitHub `develop-v2` as the source of truth.
- Replace three competing Firebase configs with canonical `firebase.json`.
- Fix the default Firebase project to `vendingnavi`.
- Remove the root legacy Firestore Rules deploy source.
- Use one Storage Rules source for production and Emulator verification.
- Require a read-only config verifier before Firebase operations.
- Provide a guarded production deployment wrapper with explicit scope, project,
  clean-tree, and Git-SHA checks.
- Add release-manifest requirements and an honest v17 audit baseline.
- Mark the old Phase 11 readiness document as superseded by NO-GO.

## Non-actions

- No Firebase deployment.
- No Firestore or Storage data write.
- No Functions deployment.
- No Play Console change.
- No versionCode 17 promotion.

## Exit criteria

- [x] GitHub contains the full Phase 11 source history.
- [x] One canonical Firebase config selects v2 Rules/indexes/Functions.
- [x] Obsolete deploy configs and legacy Rules source are absent.
- [x] Firebase project and deploy scope are explicit.
- [x] Six production Callable exports are verified.
- [x] v17 baseline manifest records known and unknown evidence.
- [x] Modified Functions tests pass (137/137).
- [ ] Unified Storage Rules Emulator tests pass.
- [ ] Firebase config contract tests pass in a Flutter-capable environment.
- [ ] Full Flutter regression passes in a Flutter-capable environment.
- [ ] Phase A changes are committed and pushed.

Phase B must not apply production migration until the remaining Phase A exit
criteria are satisfied.

The Storage Emulator gate may contain one documented skip for overwrite
immutability because the Emulator classifies a second upload as create. The
canonical Rules must still contain `allow create` and no owner `allow update`
or `allow delete` grant.
