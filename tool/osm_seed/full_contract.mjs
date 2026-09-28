import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';

import { BATCH_SIZE, COLLECTIONS, SEED_SHA, SNAPSHOT, sha256, stable } from './pilot_contract.mjs';

export const FULL_POINTS = 40788;
export const FULL_AGGREGATES = 8900;
export const FULL_TOTAL = FULL_POINTS + FULL_AGGREGATES;
export const FULL_RUN_ID = 'osm-full-20260928-01';
const ATTRIBUTION = '© OpenStreetMap contributors';

function requireCondition(condition, message) {
  if (!condition) throw new Error(message);
}

function rows(file) {
  return gunzipSync(readFileSync(file)).toString('utf8').trim().split('\n').map(JSON.parse);
}

function paths(seed, precision) {
  return seed.replace(/osm_vending_seed_jp\.ndjson\.gz$/,
    `osm_aggregate_p${precision}.ndjson.gz`);
}

function pointDocument(row) {
  const data = {
    sourceId: row.sourceId, latitude: row.latitude, longitude: row.longitude,
    geohash: row.geohash, source: 'OpenStreetMap', sourceSnapshotId: SEED_SHA,
    sourceTimestamp: SNAPSHOT, license: 'ODbL-1.0', attribution: ATTRIBUTION,
    confidence: 'tier_A_explicit_drinks', status: 'published',
  };
  for (const field of ['rawBrand', 'rawOperator']) {
    if (row[field] != null) data[field] = row[field];
  }
  return { id: row.sourceId, collection: COLLECTIONS.points,
    path: `${COLLECTIONS.points}/${row.sourceId}`, data };
}

function aggregateDocument(row) {
  const data = {
    cellId: row.cellId, precision: row.precision, geohash: row.geohash,
    count: row.count, center: row.center, bounds: row.bounds,
    sourceSnapshotId: row.sourceSnapshotId, sourceTimestamp: row.sourceTimestamp,
    source: row.source, license: row.license, attribution: ATTRIBUTION,
    status: 'published',
  };
  return { id: row.cellId, collection: COLLECTIONS.aggregates,
    path: `${COLLECTIONS.aggregates}/${row.cellId}`, data };
}

export function canonicalFullDocuments(seedPath) {
  requireCondition(/osm_vending_seed_jp\.ndjson\.gz$/.test(seedPath),
    'canonical seed filename required');
  requireCondition(sha256(readFileSync(seedPath)) === SEED_SHA, 'canonical seed SHA mismatch');
  const summary = JSON.parse(readFileSync(seedPath.replace(
    /osm_vending_seed_jp\.ndjson\.gz$/, 'aggregate_summary.json'), 'utf8'));
  requireCondition(summary.sourceSnapshotId === SEED_SHA && summary.seedRecords === FULL_POINTS,
    'aggregate summary source mismatch');
  const points = rows(seedPath).map(row => {
    requireCondition(/^osm:(node|way|relation):[1-9][0-9]*$/.test(row.sourceId) &&
      row.confidence === 'tier_A_explicit_drinks' && row.source === 'OpenStreetMap' &&
      row.license === 'ODbL-1.0' && row.sourceTimestamp === SNAPSHOT &&
      Number.isFinite(row.latitude) && Number.isFinite(row.longitude) &&
      Math.abs(row.latitude) <= 90 && Math.abs(row.longitude) <= 180 &&
      /^[0-9bcdefghjkmnpqrstuvwxyz]{6,}$/.test(row.geohash),
    `invalid canonical point: ${row.sourceId}`);
    return pointDocument(row);
  }).sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  const aggregates = [];
  const aggregateArtifacts = {};
  for (const precision of [2, 4, 6]) {
    const file = paths(seedPath, precision);
    const digest = sha256(readFileSync(file));
    requireCondition(digest === summary.precisions[String(precision)].sha256,
      `aggregate p${precision} SHA mismatch`);
    aggregateArtifacts[String(precision)] = digest;
    const items = rows(file);
    requireCondition(items.length === summary.precisions[String(precision)].cells,
      `aggregate p${precision} count mismatch`);
    let countSum = 0;
    for (const row of items) {
      requireCondition(row.cellId === `p${precision}_${row.geohash}` &&
        row.precision === precision && Number.isInteger(row.count) && row.count > 0 &&
        row.sourceSnapshotId === SEED_SHA && row.sourceTimestamp === SNAPSHOT &&
        row.source === 'OpenStreetMap' && row.license === 'ODbL-1.0' &&
        row.center && row.bounds, `invalid aggregate: ${row.cellId}`);
      countSum += row.count;
      aggregates.push(aggregateDocument(row));
    }
    requireCondition(countSum === FULL_POINTS, `aggregate p${precision} count sum mismatch`);
  }
  aggregates.sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  requireCondition(points.length === FULL_POINTS && aggregates.length === FULL_AGGREGATES &&
    new Set(points.map(doc => doc.id)).size === FULL_POINTS &&
    new Set(aggregates.map(doc => doc.id)).size === FULL_AGGREGATES,
  'canonical full count or duplicate mismatch');
  return { points, aggregates, aggregateArtifacts };
}

export function fullManifest(source, runId = FULL_RUN_ID) {
  requireCondition(/^osm-full-[0-9]{8}-[0-9]{2}$/.test(runId), 'invalid full run ID');
  return {
    schemaVersion: 2, mode: 'full', runId,
    sourceSnapshot: SNAPSHOT, seedSha256: SEED_SHA,
    license: 'ODbL-1.0', attribution: ATTRIBUTION, collections: COLLECTIONS,
    aggregateArtifacts: source.aggregateArtifacts,
    expectedPoints: FULL_POINTS, expectedAggregates: FULL_AGGREGATES,
    expectedTotal: FULL_TOTAL,
    points: source.points.map(doc => doc.id),
    aggregates: source.aggregates.map(doc => doc.id),
  };
}

export function validateFullManifest(manifestPath, seedPath, approvedManifestSha) {
  const bytes = readFileSync(manifestPath);
  const manifestSha256 = sha256(bytes);
  if (approvedManifestSha) requireCondition(
    manifestSha256 === approvedManifestSha.toLowerCase(), 'manifest SHA mismatch');
  const manifest = JSON.parse(bytes.toString('utf8'));
  requireCondition(manifest.schemaVersion === 2 && manifest.mode === 'full' &&
    /^osm-full-[0-9]{8}-[0-9]{2}$/.test(manifest.runId), 'full manifest required');
  requireCondition(stable(manifest.collections) === stable(COLLECTIONS),
    'collection allowlist mismatch');
  requireCondition(manifest.seedSha256 === SEED_SHA && manifest.sourceSnapshot === SNAPSHOT &&
    manifest.license === 'ODbL-1.0' && manifest.attribution === ATTRIBUTION,
  'full manifest provenance mismatch');
  requireCondition(manifest.expectedPoints === FULL_POINTS &&
    manifest.expectedAggregates === FULL_AGGREGATES &&
    manifest.expectedTotal === FULL_TOTAL &&
    Array.isArray(manifest.points) && manifest.points.length === FULL_POINTS &&
    Array.isArray(manifest.aggregates) && manifest.aggregates.length === FULL_AGGREGATES,
  'full manifest count mismatch');
  const source = canonicalFullDocuments(seedPath);
  requireCondition(stable(manifest.aggregateArtifacts) === stable(source.aggregateArtifacts),
    'aggregate artifact SHA mismatch');
  for (let i = 0; i < FULL_POINTS; i++) {
    requireCondition(manifest.points[i] === source.points[i].id,
      `full point ID/order mismatch at ${i}`);
  }
  for (let i = 0; i < FULL_AGGREGATES; i++) {
    requireCondition(manifest.aggregates[i] === source.aggregates[i].id,
      `full aggregate ID/order mismatch at ${i}`);
  }
  const documents = [...source.points, ...source.aggregates];
  return { manifest, manifestSha256, documents };
}

export function fullChunks(documents) {
  const chunks = [];
  for (let start = 0; start < documents.length; start += BATCH_SIZE) {
    const entries = documents.slice(start, start + BATCH_SIZE);
    chunks.push({
      id: String(chunks.length).padStart(6, '0'), index: chunks.length,
      start, endExclusive: start + entries.length, entries,
      sha256: sha256(Buffer.from(JSON.stringify(entries.map(doc =>
        ({ path: doc.path, data: doc.data }))))),
    });
  }
  return chunks;
}
