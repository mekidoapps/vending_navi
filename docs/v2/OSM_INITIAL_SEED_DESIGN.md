# OSM initial vending seed — pre-production design

Status: preparation only. No Production Firestore import, Hosting deploy, Play submission, or AAB build is authorized by this document.

## Provenance and candidate contract

- Bulk source: one Japan OSM PBF extract from Geofabrik. Filter version `drink-v1` in `tool/osm_seed/extract_japan_pbf.py`.
- Tier A: `amenity=vending_machine` and a `vending` token exactly equal to `drinks`. This is a location candidate, not proof of current machine operation or stock.
- Tier B: vending tag absent/ambiguous and `brand` or `operator` matches the conservative beverage-brand table. Tier B is counted separately and is **not imported automatically**.
- Explicitly non-drink vending tags are excluded unless `drinks` is also explicit. Unknown values remain unknown.
- Brand precedence is `brand`, then `operator`. `manufacturer` remains the raw *machine manufacturer* tag and never implies a beverage/product maker. No product, price, inventory, or photo is inferred.
- Stable key: `osm:node:<id>` or `osm:way:<id>`. Tagged relations without a safely resolved point are counted but withheld from the seed. A way location is the mean of available member-node coordinates and needs pre-import review.
- The canonical local artifact is a sorted, compressed NDJSON seed with source/license metadata. The input PBF and any native comparison coordinates stay in ignored local build/temporary storage, not Git.

Attribution: © OpenStreetMap contributors. Open Database License (ODbL) 1.0. See <https://www.openstreetmap.org/copyright> and <https://opendatacommons.org/licenses/odbl/1-0/>. Prefecture reporting uses geoBoundaries `gbOpen/JPN/ADM1`, sourced from OpenStreetMap/Wambacher and marked ODbL 1.0. Its geometry is analysis-only, not merged into the vending seed.

## Data separation

Proposed source collection: `osm_vending_seed/{sourceId}`. Store source ID, OSM element type/ID, latitude/longitude, geohash, narrow raw tag subset, independent raw brand/operator/manufacturer, normalized brand candidate, vending tag, snapshot timestamp, ODbL license, confidence tier, and import status/time. Keep source snapshots immutable by version; never replace the original OSM tags with user edits. Do not insert these documents into native `vending_machines` or `machine_product_index`.

Native `vending_machines` continues to own registered machines, products, public photos, corrections, reports, favorites, and block state. If a native machine relates to an OSM candidate, use a separate explicit reference such as `{source: 'osm', sourceId: 'osm:node:...'}` and preserve both identities. Proximity is a manual-review signal, not an automatic merge or a product inference. Independently contributed details should not be copied back into the OSM source dataset without a separate provenance/license decision.

**Read-path implementation (not deployed):** the Flutter map now has a separate read-only OSM viewport/detail adapter and source-prefixed navigation. Wide and mid zoom use precomputed geohash aggregate cells; individual points are queried only at near zoom with a global result budget. The map uses camera-idle debounce, stale-response rejection, session cache, bounded marker rendering and OSM point clustering. The product/genre search layer hides OSM candidates, whose inventory is unknown. Firestore rules and indexes for the separate seed/aggregate collections are source-only and have not been deployed. `machine_product_index`, registration duplicate checks, corrections, photos, reports, favorites and blocking still assume native machine IDs; the native update/product/report flows must not silently write against an OSM document. No OSM seed or aggregate data has been imported into Production, so the implementation must not be treated as live-map evidence.

Aggregate artifacts are generated deterministically from the locked 40,788-record seed at geohash precisions 2, 4 and 6 by `tool/osm_seed/build_aggregate_cells.py`. They contain cell count, center, bounds and source snapshot/license metadata but no raw tag payload. They are ODbL-derived candidates with `candidate_not_imported` status. `tool/osm_seed/benchmark_viewports.py` records dense and ordinary viewport estimates in `viewport_benchmarks.json`; these offline estimates are not a substitute for device-profile measurements or Production read evidence. Any later import needs separate approval and must promote only reviewed candidate documents to a published status after rules/index and licensing checks.

Separation classification: **PARTIALLY_COUPLED** (source artifacts and read-only map paths are separate; native write/reference paths and ODbL-derived-data boundaries still require review). This is an engineering assessment, not a legal opinion.

## Import plan (not implemented for Production)

`tool/osm_seed/plan_import.py` validates the local artifact, stable IDs, Tier A, coordinates, attribution, and absence of inferred product/user fields. It is a dry run only and contains no Firebase write client.

A later, separately approved importer must:

1. Verify SHA-256 and source metadata; compare expected count to validated records; reject schema, license, coordinate, or source-ID anomalies.
2. Read current native and prior OSM IDs; produce manual-review overlap lists. Skip unresolved, duplicate, or rejected IDs. Never merge native and OSM documents automatically.
3. Use deterministic document IDs from `sourceId`, idempotent create/compare behavior, batches at most 400, bounded request rate, retry limits, and an approval gate before writes.
4. Record pre-import, created, unchanged/skipped, overlap-reviewed, error and post-import counts, plus a batch-to-source-ID rollback manifest. Rollback must target only documents created by that import run.
5. Validate live rules, indexes, read-only map/detail behavior, attribution, and native regression before a new Android RC. No Production import should start while the current integration gap remains.

## Public snapshot and release impact

The actual OSM subset used in Production should have a public downloadable compressed NDJSON/CSV snapshot (or an equivalent ODbL-compliant data-access mechanism), with extraction date, filter version, schema and license file linked from `/data-licenses`. Decide hosting size, retention/versioning and legal review before publication. This phase does not publish the snapshot or Hosting page.

Flutter runtime changes supersede RC20 for Production. The existing 1.0.0 (20) Production draft must not be submitted. The next proposed versionCode is 21; neither version nor AAB is changed in this phase.
