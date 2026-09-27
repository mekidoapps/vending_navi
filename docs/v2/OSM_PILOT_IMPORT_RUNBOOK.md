# OSM pilot import — source-only operating contract

Status: tooling and the 752-document manifest are prepared. **No Production OSM import, Rules/Indexes deploy, or Hosting publish has occurred.** Production execution requires a separate explicit approval for the exact manifest SHA and new source commit.

## Collection and license contract

- Public points: `osm_vending_seed/{sourceId}`.
- Public aggregate cells: `osm_vending_aggregate/{cellId}`. `osm_vending_cells` is not a Firestore collection.
- Server-only run evidence: `osm_import_runs/{runId}`; client get/list/write are denied. No new index is required for a document-by-ID lookup.
- Each public document is a minimal projection from the locked 40,788-record seed (SHA-256 `0b51408d8cf648603d1db0eccd8f0ae06ce691ba42ddae2762456f66658c0e17`), with ODbL 1.0 attribution. Raw tags, products, photos, import ownership and credentials are not copied to public documents.
- The fixed candidate is `outputs/osm_seed/2026-09-26/osm_pilot_20260927_01.manifest.json`: 346 points + 406 aggregates = 752. Four areas: Tokyo dense, Osaka dense, normal urban, suburban. No optional native-mix addition is in this manifest. Maximum supported by this pilot tool: 900 public OSM documents.

## Before any Production execution

1. Confirm `origin/develop-v2`, the approved new source commit, clean operator checkout, canonical seed SHA, exact manifest SHA, and the 752 paths. Re-run `node tool/osm_seed/pilot_import.mjs --pilot-manifest outputs/osm_seed/2026-09-26/osm_pilot_20260927_01.manifest.json`; default is offline dry-run with **zero Firebase connections/writes**.
2. Obtain separate authorization for the exact manifest SHA and Production mutation. Read and preserve current Rules, index states and OSM counts. Deploy only the approved Firestore Rules and the two OSM indexes; verify live Rules byte/semantic alignment and both indexes READY. Do not import before these checks pass.
3. Review native-machine overlap and public ODbL snapshot/attribution release requirements separately. This tool never edits native/user collections and does not perform an automatic native merge.

## Explicit execution gates (future approved phase only)

The CLI accepts only the three OSM collections above. `--execute`, exact `--project vendingnavi`, matching `--confirm-project vendingnavi`, `--run-id`, `--pilot-manifest` and `--manifest-sha256` are all required for a Production write. The CLI verifies the canonical seed and selected rows against the aggregate artifacts *before* opening Firestore. Wrong project, wrong hash, invalid ID/tier, conflict or >900 documents are rejected before the first data write. The operator must substitute the independently approved manifest hash; do not copy an unreviewed value from tool output.

```text
node tool/osm_seed/pilot_import.mjs --pilot-manifest <exact-file> --seed <canonical-seed> --execute --project vendingnavi --confirm-project vendingnavi --run-id <approved-run-id> --manifest-sha256 <approved-sha256>
```

The tool pre-reads all target paths and refuses differing existing documents. It creates/updates in transactions of at most 100 public documents plus the run document. Repeated execution skips identical documents and never overwrites conflicts. The run document atomically records newly created paths, counts and progress with each transaction, allowing a `PARTIAL`/`FAILED` run to resume by the same run ID and manifest. It does **not** automatically delete data after a partial failure.

## Rollback

First perform a read-only rollback plan with the same project, run ID and approved manifest hash, adding `--rollback` but **not** `--execute`. It lists only paths the run actually created. A different or changed public document is a conflict and stops rollback. After separate review, add `--execute --rollback` to delete only those run-owned OSM paths. Other-run OSM and native/user documents are never targeted. The run metadata remains server-only as rollback evidence.

An interrupted rollback records partial progress. Stop and review before resuming; do not issue broad collection deletes. Do not remove the run metadata by hand. Full 40,788-record import, Tier B import, native conversion, Hosting publish and RC21 build are outside this contract.
