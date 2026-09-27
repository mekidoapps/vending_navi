import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';

export const COLLECTIONS = Object.freeze({
  points: 'osm_vending_seed',
  aggregates: 'osm_vending_aggregate',
  runs: 'osm_import_runs',
});
export const SEED_SHA = '0b51408d8cf648603d1db0eccd8f0ae06ce691ba42ddae2762456f66658c0e17';
export const SNAPSHOT = '2026-09-25T20:24:36Z';
export const CAP = 900;
export const BATCH_SIZE = 100;
const attribution = '© OpenStreetMap contributors';
const pointFields = new Set(['sourceId', 'latitude', 'longitude', 'geohash',
  'source', 'sourceSnapshotId', 'sourceTimestamp', 'license', 'attribution',
  'confidence', 'status', 'rawBrand', 'rawOperator']);
const aggregateFields = new Set(['cellId', 'precision', 'geohash', 'count',
  'center', 'bounds', 'source', 'sourceSnapshotId', 'sourceTimestamp',
  'license', 'attribution', 'status']);

export function sha256(bytes) {
  return createHash('sha256').update(bytes).digest('hex');
}

export function stable(value) {
  if (Array.isArray(value)) return `[${value.map(stable).join(',')}]`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(k => `${JSON.stringify(k)}:${stable(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value);
}

function ensure(condition, message) {
  if (!condition) throw new Error(message);
}

function ndjsonGzip(file) {
  return gunzipSync(readFileSync(file)).toString('utf8').trim().split('\n').map(JSON.parse);
}

export function validateManifest(manifestPath, seedPath, approvedSha) {
  const bytes = readFileSync(manifestPath);
  const manifestSha256 = sha256(bytes);
  if (approvedSha) ensure(manifestSha256 === approvedSha.toLowerCase(), 'manifest SHA mismatch');
  const manifest = JSON.parse(bytes.toString('utf8'));
  ensure(manifest.schemaVersion === 1 && manifest.mode === 'pilot', 'pilot manifest required');
  ensure(/^osm-pilot-[0-9]{8}-[0-9]{2}$/.test(manifest.runId), 'invalid run ID');
  ensure(stable(manifest.collections) === stable(COLLECTIONS), 'collection allowlist mismatch');
  ensure(manifest.seedSha256 === SEED_SHA && sha256(readFileSync(seedPath)) === SEED_SHA,
    'canonical seed SHA mismatch');
  ensure(manifest.sourceSnapshot === SNAPSHOT && manifest.license === 'ODbL-1.0' &&
    manifest.attribution === attribution, 'provenance mismatch');
  ensure(typeof manifest.createdAt === 'string' && !Number.isNaN(Date.parse(manifest.createdAt)),
    'manifest creation time missing');
  ensure(Object.keys(manifest.areas ?? {}).sort().join('|') ===
    ['Tokyo dense', 'Osaka dense', 'normal urban', 'suburban'].sort().join('|'),
  'pilot areas mismatch');
  ensure(Array.isArray(manifest.points) && Array.isArray(manifest.aggregates), 'document arrays missing');
  const all = [...manifest.points.map(doc => ({ ...doc, collection: COLLECTIONS.points })),
    ...manifest.aggregates.map(doc => ({ ...doc, collection: COLLECTIONS.aggregates }))];
  ensure(all.length <= CAP && all.length > 0, 'pilot hard cap exceeded');
  ensure(manifest.expectedPoints === manifest.points.length &&
    manifest.expectedAggregates === manifest.aggregates.length &&
    manifest.expectedTotal === all.length, 'planned count mismatch');
  const paths = new Set();
  for (const doc of all) {
    ensure(typeof doc.id === 'string' && doc.data && typeof doc.data === 'object', 'invalid document');
    doc.path = `${doc.collection}/${doc.id}`;
    ensure(!paths.has(doc.path), `duplicate document: ${doc.path}`);
    paths.add(doc.path);
    const allowed = doc.collection === COLLECTIONS.points ? pointFields : aggregateFields;
    ensure(Object.keys(doc.data).every(key => allowed.has(key)), `nonpublic field: ${doc.path}`);
    ensure(doc.data.status === 'published' && doc.data.source === 'OpenStreetMap' &&
      doc.data.license === 'ODbL-1.0' && doc.data.attribution === attribution &&
      doc.data.sourceSnapshotId === SEED_SHA && doc.data.sourceTimestamp === SNAPSHOT,
    `invalid provenance: ${doc.path}`);
    if (doc.collection === COLLECTIONS.points) {
      ensure(/^osm:(node|way|relation):[1-9][0-9]*$/.test(doc.id) &&
        doc.data.sourceId === doc.id && doc.data.confidence === 'tier_A_explicit_drinks' &&
        Number.isFinite(doc.data.latitude) && Number.isFinite(doc.data.longitude) &&
        Math.abs(doc.data.latitude) <= 90 && Math.abs(doc.data.longitude) <= 180 &&
        /^[0-9bcdefghjkmnpqrstuvwxyz]{6,}$/.test(doc.data.geohash),
      `invalid Tier-A point: ${doc.path}`);
    } else {
      const match = /^p([246])_([0-9bcdefghjkmnpqrstuvwxyz]+)$/.exec(doc.id);
      ensure(match && doc.data.cellId === doc.id && doc.data.precision === Number(match[1]) &&
        doc.data.geohash === match[2] && Number.isInteger(doc.data.count) &&
        doc.data.count > 0 && doc.data.center && doc.data.bounds,
      `invalid aggregate: ${doc.path}`);
    }
  }

  // Validate every selected public value against the locked source artifacts,
  // not just manifest counts and the seed file hash.
  const seedRows = new Map(ndjsonGzip(seedPath).map(row => [row.sourceId, row]));
  for (const doc of manifest.points) {
    const row = seedRows.get(doc.id);
    ensure(row && row.confidence === 'tier_A_explicit_drinks' &&
      row.latitude === doc.data.latitude && row.longitude === doc.data.longitude &&
      row.geohash === doc.data.geohash &&
      (row.rawBrand ?? undefined) === doc.data.rawBrand &&
      (row.rawOperator ?? undefined) === doc.data.rawOperator,
    `point differs from canonical seed: ${doc.id}`);
  }
  const aggregateRows = new Map();
  const summaryPath = seedPath.replace(/osm_vending_seed_jp\.ndjson\.gz$/, 'aggregate_summary.json');
  const aggregateSummary = JSON.parse(readFileSync(summaryPath, 'utf8'));
  ensure(aggregateSummary.sourceSnapshotId === SEED_SHA, 'aggregate summary seed mismatch');
  for (const p of [2, 4, 6]) {
    const path = seedPath.replace(/osm_vending_seed_jp\.ndjson\.gz$/, `osm_aggregate_p${p}.ndjson.gz`);
    ensure(sha256(readFileSync(path)) === aggregateSummary.precisions[String(p)].sha256,
      `aggregate p${p} SHA mismatch`);
    for (const row of ndjsonGzip(path)) aggregateRows.set(row.cellId, row);
  }
  for (const doc of manifest.aggregates) {
    const row = aggregateRows.get(doc.id);
    ensure(row && row.precision === doc.data.precision && row.geohash === doc.data.geohash &&
      row.count === doc.data.count && stable(row.center) === stable(doc.data.center) &&
      stable(row.bounds) === stable(doc.data.bounds),
    `aggregate differs from canonical artifact: ${doc.id}`);
  }
  return { manifest, manifestSha256, documents: all };
}
