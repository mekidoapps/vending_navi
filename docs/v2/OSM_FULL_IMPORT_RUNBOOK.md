# OSM full import — source-only operating contract

Status: full-mode tooling and the canonical manifest are prepared and emulator-tested. **Production execution, Rules deploy, and any additional OSM write are not authorized by this document.** The existing 752-document pilot remains owned by `osm-pilot-20260927-01`.

## Identity and scope

- Run ID: `osm-full-20260928-01`; mode: `full`.
- Manifest: `outputs/osm_seed/2026-09-26/osm_full_20260928_01.manifest.json` (schema 2, ID-only, deterministic).
- Manifest SHA-256: `538365bb60bce679147da956c2388d0785c5388e2cdacd3cedb24e0bd3d7b2c0`.
- Seed SHA-256: `0b51408d8cf648603d1db0eccd8f0ae06ce691ba42ddae2762456f66658c0e17`.
- Aggregate precisions 2 / 4 / 6: 7 / 550 / 8,343 cells. Total: 8,900.
- Expected full public documents: 40,788 points + 8,900 aggregates = 49,688.
- Expected current-pilot reconciliation: 752 identical skips; 48,936 new creates; zero conflicts. Before execution these values must be obtained again from read-only Production preflight.
- Only `osm_vending_seed`, `osm_vending_aggregate`, and `osm_import_runs/{runId}` with its `chunks` subcollection are in scope. No native/user writes, automatic proximity merge, or Tier B import.

The full tool reconstructs minimal public documents from the hash-locked seed and aggregate artifacts. The manifest carries all stable IDs and hashes, not public data copies. `node tool/osm_seed/build_full_manifest.mjs` regenerates identical bytes; a different manifest SHA requires a new review. The pilot CLI and its 900-document cap are unchanged.

## Offline and read-only gates

The following does not initialize Firebase:

```text
node tool/osm_seed/full_import.mjs --mode full --manifest outputs/osm_seed/2026-09-26/osm_full_20260928_01.manifest.json
```

The Production preflight requires the exact approved SHA values, project confirmation and run ID, but does not write:

```text
node tool/osm_seed/full_import.mjs --mode full --manifest <exact-manifest> --read-only-preflight --project vendingnavi --confirm-project vendingnavi --run-id osm-full-20260928-01 --approved-manifest-sha <approved-manifest-sha> --approved-seed-sha <approved-seed-sha>
```

It reads all 49,688 target paths and checks both collection counts, all content, and pilot run ownership. Any conflict, missing pilot-owned document, unexpected outside-manifest OSM document, hash mismatch, or project mismatch stops before a write. Client Rules deny access to the run root and chunks; Admin SDK/server IAM is required.

## Separately authorized execution and resume

Only after a separate explicit Production authorization for the exact source commit, manifest SHA and run ID, add `--execute --confirm-full-import` to the same explicit project/hash invocation. Do not pass `--rollback`. A fresh run root is created after full preflight. The manifest is split into 497 stable 100-entry chunks (`000000`–`000496`). Each chunk uses one atomic create-only WriteBatch for missing public documents and its ownership record. Identical pre-existing documents are skips and are never acquired as full-run ownership. The root stores summary and lifecycle fields only; progress is the chunk subcollection.

If a batch fails, stop. The last committed chunk and its created-ID ownership remain together, while the failed chunk commits neither. No automatic rollback occurs. After investigating, the **same** run ID, source, manifest and approval values can be used to resume; completed chunks are validated and skipped. Changed or missing completed documents are conflicts, not silently repaired. An emulator-only failure flag exists for tests and is refused against Production.

## Manual rollback

Rollback is never automatic. First run the explicit project/hash invocation with `--rollback` but **without** `--execute`; review the run-owned count. After separate rollback approval, add `--execute --confirm-full-rollback`. The tool processes completed chunks in reverse order. Each atomic batch conditionally deletes only IDs recorded as created by that full-run chunk and marks the same chunk `ROLLED_BACK`. Changed or missing owned documents stop the process; a partially rolled-back run can be resumed with the same command. Already rolled-back chunks are skipped and expected to remain absent. The root and chunks remain as server-only audit evidence.

The pilot's 346 points and 406 aggregates are checked against the canonical manifest and protected ownership list before full execution or rollback. They are not full-run-created IDs and must remain after rollback. The expected post-rollback counts are 346 / 406. Never delete a collection or run metadata by hand.
