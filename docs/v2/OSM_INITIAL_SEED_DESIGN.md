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

**Current integration gap:** the Flutter viewport and detail repositories read `vending_machines` only. `machine_product_index`, registration duplicate checks, corrections, photos, reports, favorites and blocking also assume native machine IDs. The attribution screen and OSM-only source-label component are implemented, but a source-prefixed OSM ID cannot currently be loaded from the separate collection in Production. A future read-only OSM viewport/detail adapter, navigation, security rules and query index must be implemented and tested before importing or surfacing the seed. The native update/product/report flows must not silently write against an OSM document. Until these gates pass, do not import seed data and do not present OSM markers as live.

Separation classification: **PARTIALLY_COUPLED** (source artifact and proposed storage are separate; app read/reference paths and ODbL-derived-data boundaries are not fully established). This is an engineering assessment, not a legal opinion.

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
