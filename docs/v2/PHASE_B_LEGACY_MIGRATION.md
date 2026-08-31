# Phase B: production backup and legacy migration

**Status: IN PROGRESS (2026-08-31)**

## Scope and safety boundary

Phase B classifies all 42 production `vending_machines` documents, creates a
recoverable pre-migration snapshot, and prepares an idempotent migration. No
production document may be changed until the backup, dry-run, count review,
explicit approval, and rollback gates below are complete.

The old `backfill_legacy_machine_status.ts` command is retired. It treated a
missing status as `active`, which is not supported by the v1 source or the
production audit evidence.

## Evidence from the v1 source

- The v1 `VendingMachine` model did not define or read a machine status.
- The v1 create and update services did not write a machine status.
- Therefore production `status: available` has no established machine-level
  meaning in the tracked v1 source.
- Product availability also uses the word `available`, so carrying that value
  into v2 machine visibility would be an unsupported inference.
- The tracked v1 Firestore Rules allowed every vending-machine document to be
  read, and the v1 app loaded the collection without a status filter.
- Consequently all 41 non-v2 documents were effectively public in v1. Using
  that effective visibility as the v2 status source is recommended, but is not
  implemented until the owner records an explicit decision.

## Status mapping table

This table is explicit and is implemented by the read-only planner. A null
target is a hard stop for migration, not a hidden default.

| Legacy value | Target | Decision |
|---|---|---|
| `active` | `active` | Canonical value; may remain public |
| `underReview` | `underReview` | Canonical value; do not index |
| `hidden` | `hidden` | Canonical value; do not index |
| `merged` | `merged` | Canonical value; do not index |
| `removed` | `removed` | Canonical value; do not index |
| `available` | none | Manual review required |
| `unavailable` | none | Manual review required |
| `deleted` | none | Not a v2 machine status; manual review required |
| Missing/blank | none | Manual review required |
| Any other value | none | Manual review required |

Mapping `available` or a missing value to `active` requires separate evidence
or an explicit owner decision recorded before the apply implementation is
created.

## Read-only dry-run tool

`functions/scripts/plan_legacy_machine_migration.ts` accepts only an offline
JSON export. It has no Firestore client and rejects `--apply` and
`--allow-production`.

Expected export shape:

```json
{
  "documents": [
    {
      "id": "machine-id",
      "data": {
        "status": "active",
        "lat": 35.681236,
        "lng": 139.767125,
        "products": [{"name": "商品名"}]
      }
    }
  ]
}
```

Run from `functions/`:

```bash
npm run plan:legacy-migration -- \
  --input=/secure/path/legacy-machines.json \
  --master=fixtures/master_fixture.json \
  --output=/secure/path/legacy-migration-plan.json
```

Optional aliases are JSON objects keyed by the same normalized exact label
used by the master resolver:

```json
{
  "manufacturers": {"旧メーカー名": "canonical_manufacturer_id"},
  "products": {"旧商品名": "canonical_product_id"}
}
```

The report is sorted by machine ID and contains legacy/target status,
coordinates, geohash, manufacturer resolution, every legacy product,
resolved IDs, unresolved raw names, source/target schema versions, planned
index count, and warnings. Reordering the same input does not change output.

## Product and index rules

Resolution order is deterministic:

1. exact active Product ID;
2. explicit manual alias to an active Product ID;
3. unique exact normalized name/search keyword;
4. unique manufacturer plus exact normalized label;
5. unresolved, retaining the raw name.

There is no fuzzy or partial match. Duplicate machine/product pairs count once.
Indexes are planned only for `active` machines with valid coordinates and
resolved active Product IDs. Under-review, hidden, merged, removed,
review-required, invalid-coordinate, and unresolved-product cases never gain
an index implicitly.

## Backup gate before any write

The following evidence must be captured together and identified by UTC time,
Firebase project ID, source Git SHA, and SHA-256 where applicable:

- managed Firestore export and verified restore target;
- current Firestore and Storage Rules snapshots;
- deployed Functions names and revisions;
- exact 42-document JSON export;
- master fixture hash;
- pre-migration counts for roots, product subcollections, indexes, and photos.

PITR or scheduled backups should be enabled separately, but enabling them does
not replace the point-in-time export required for this migration.

## Apply and rollback gates

An apply implementation is intentionally absent at this stage. It may be added
only after the 42-document report has no unapproved status decisions and the
backup has been verified.

Before apply:

- [ ] Report total is exactly 42.
- [ ] Every `available`, missing, and unknown status has a recorded decision.
- [ ] Every invalid coordinate has a recorded correction or exclusion.
- [ ] Every unresolved product remains preserved as raw evidence.
- [ ] Planned public root and index counts are approved.
- [ ] Backup restore procedure and rollback owner are recorded.
- [ ] Exact source commit and migration revision are recorded.
- [ ] Explicit production apply approval is recorded.

After apply, rollback is triggered by a count mismatch, missing public machine,
unexpected index, lost raw product/photo/timestamp, or a non-zero second-run
diff. No legacy field or document is deleted during Phase B.

## Current verification

- Functions build: passed.
- Functions regression: 143 passed, 0 failed.
- Migration planner tests: 6 passed, including status non-inference, invalid
  coordinates, exact resolution, ambiguity, aliases, duplicate IDs, and input
  order idempotency.
- Fixture dry-run: passed (`total=3`, `ready=1`, `manualReview=2`,
  `invalidCoordinates=1`, `unresolvedProducts=1`, `plannedIndexes=1`).
- Production sanitized read-only snapshot: 42/42 documents classified.
- Production status counts: `active=1`, `available=34`, `missing=7`.
- Valid coordinate pairs: 42/42; existing geohash: 1/42; schemaVersion 2: 1/42.
- Baseline product resolution: 34 legacy entries, 22 resolved, 12 unresolved.
- Four exact alias candidates were tested privately; they reduce unresolved
  entries to 8, but are not committed or applied without owner approval.
- Sanitized snapshot SHA-256:
  `6543912ef131256154c8698b75722b5da79dcb662dfd01e15ab188d4aa291be0`.
- Baseline dry-run report SHA-256:
  `2fa466cb726d3265d198ac01221d7d4d38b80989a6b79d67445a2e967bd2a3fb`.
- Master fixture SHA-256:
  `334601845df4078be983c93fd8b43aa1ec74226101e208018a3ab13a0dca939d`.
- The sanitized snapshot and detailed report contain production-derived
  location/product data and are intentionally not committed to GitHub.
- Production writes: none.
