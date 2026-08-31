# Firebase release operations

## Scope

This is the canonical procedure for deploying VendingNavi v2 Firestore Rules,
indexes, Storage Rules, or Functions. It does not authorize a deployment by
itself. Production changes still require the phase-specific backup, dry-run,
approval, and rollback evidence.

## Preconditions

1. The release source is committed and pushed.
2. The working tree is clean.
3. The intended Git SHA is recorded in the release manifest.
4. Relevant automated and Emulator tests passed from that SHA.
5. A before snapshot and rollback procedure exist for the target resource.
6. The production change has explicit approval.

## Read-only verification

```bash
tool/verify_firebase_release_config.sh
git status --short
git rev-parse HEAD
```

The verifier requires:

- Firebase project `vendingnavi`
- canonical `firebase.json`
- v2 Firestore Rules and indexes
- production Storage Rules
- Functions codebase `v2`
- all six release Callable exports
- absence of obsolete deploy configuration files

## Guarded deployment

Set both values explicitly in the same shell that performs the approved
deployment:

```bash
export VENDING_NAVI_DEPLOY_PROJECT=vendingnavi
export VENDING_NAVI_RELEASE_SHA="$(git rev-parse HEAD)"
```

Deploy one explicit scope, or a comma-separated combination of these scopes:

```text
functions:v2
firestore:rules
firestore:indexes
storage
```

Example:

```bash
tool/deploy_firebase_production.sh functions:v2
```

The script blocks unsupported scopes, a dirty working tree, a project mismatch,
a Git SHA mismatch, missing Callable exports, or obsolete config files.

## Evidence after deployment

Record in the release manifest:

- command scope
- Git SHA
- deployment timestamp
- deployed Functions revisions
- Firestore Rules hash
- Storage Rules hash
- smoke-test result
- operator
- rollback decision

Do not continue to a release build if the deployed source cannot be tied back to
the same manifest and Git SHA.
