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
- Consequently all 41 non-v2 documents were effectively public in v1.

## Owner decisions recorded on 2026-08-31

- Preserve the effective v1 visibility of the 41 non-v2 documents by assigning
  `active` to the exact 41 machine IDs in the private status-decisions file.
- Do not make `available` or a missing status a global mapping rule. A future
  document without an exact machine-ID decision remains a hard stop.
- Adopt only these four normalized exact product aliases:
  - `タリーズ バリスタブラック` -> `ito_en_tullys_coffee_black`
  - `ポカリスエット 缶` -> `otsuka_pocari_sweat`
  - `ミネラル麦茶` -> `ito_en_kenko_mineral_mugicha`
  - `boss レインボーマウンテン` ->
    `suntory_boss_rainbow_mountain_blend`
- Preserve the remaining eight unresolved product labels as raw migration
  evidence; do not guess or create Product IDs for them.

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
| `available` | `active` only for 34 approved machine IDs | Owner-approved v1 visibility preservation |
| `unavailable` | none | Manual review required |
| `deleted` | none | Not a v2 machine status; manual review required |
| Missing/blank | `active` only for 7 approved machine IDs | Owner-approved v1 visibility preservation |
| Any other value | none | Manual review required |

Any `available` or missing value without an exact machine-ID decision remains
manual review. Canonical v2 statuses cannot be overridden by a decision file.

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
  --aliases=fixtures/legacy_machine_migration_aliases.json \
  --status-decisions=/secure/path/approved-status-decisions.json \
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

Status decisions are keyed by exact machine ID and remain outside GitHub:

```json
{
  "machineStatuses": {
    "exact-exported-machine-id": "active"
  }
}
```

The planner rejects stale machine IDs, non-canonical target values, and any
attempt to override a canonical v2 status.

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

### Managed export gate (completed)

- A managed pre-migration Firestore export completed successfully.
- Detailed export evidence is retained outside GitHub in private storage.
- Production migration remains blocked until an isolated non-production restore
  is verified.

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
- Functions regression: 146 passed, 0 failed.
- Migration planner tests: 9 passed, including status non-inference,
  owner-approved per-machine decisions, stale-decision rejection, canonical
  status protection, invalid coordinates, exact resolution, ambiguity,
  approved aliases, duplicate IDs, and input-order idempotency.
- Fixture dry-run: passed (`total=3`, `ready=1`, `manualReview=2`,
  `invalidCoordinates=1`, `unresolvedProducts=1`, `plannedIndexes=1`).
- Production sanitized read-only snapshot: 42/42 documents classified.
- Production status counts: `active=1`, `available=34`, `missing=7`.
- Valid coordinate pairs: 42/42; existing geohash: 1/42; schemaVersion 2: 1/42.
- Baseline product resolution: 34 legacy entries, 22 resolved, 12 unresolved.
- Owner-approved dry-run: `total=42`, `ready=42`, `manualReview=0`,
  `invalidCoordinates=0`, `unresolvedProducts=8`, `plannedIndexes=25`.
- Status decision outcomes: 1 canonical and 41 owner-approved.
- The four approved exact aliases reduce unresolved entries from 12 to 8.
- Sanitized snapshot SHA-256:
  `6543912ef131256154c8698b75722b5da79dcb662dfd01e15ab188d4aa291be0`.
- Baseline dry-run report SHA-256:
  `2fa466cb726d3265d198ac01221d7d4d38b80989a6b79d67445a2e967bd2a3fb`.
- Master fixture SHA-256:
  `334601845df4078be983c93fd8b43aa1ec74226101e208018a3ab13a0dca939d`.
- Approved alias fixture SHA-256:
  `a8692e16146670d382a5ec514af9cb066e82ae18110d65c55146b26f2177dcdd`.
- Private status-decisions SHA-256:
  `036ee7264c24df3af4dac47cbdf07d46844ab7cf4cccf9f78c24ace1e0771e44`.
- Approved dry-run report SHA-256:
  `9ea705ee23b50c25059d2b536e1df5b7c6a5328a310297c777c86f3f6cd873e8`.
- The sanitized snapshot and detailed report contain production-derived
  location/product data and are intentionally not committed to GitHub.
- The backup gate remains open; an apply implementation is still absent.
- Production writes: none.
