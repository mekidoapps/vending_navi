import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';

import { sha256 } from './pilot_contract.mjs';
import { buildFullManifest } from './build_full_manifest.mjs';
import { fullChunks, validateFullManifest } from './full_contract.mjs';
import { chunkMetadata, main, rootMetadata } from './full_import.mjs';

const root = resolve(import.meta.dirname, '../..');
const seed = join(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');
const manifestPath = join(root, 'outputs/osm_seed/2026-09-26/osm_full_20260928_01.manifest.json');

test('full manifest is complete, deterministic and offline dry-run only', async () => {
  const contract = validateFullManifest(manifestPath, seed);
  assert.equal(contract.manifest.mode, 'full');
  assert.equal(contract.manifest.expectedPoints, 40788);
  assert.equal(contract.manifest.expectedAggregates, 8900);
  assert.equal(contract.documents.length, 49688);
  const specs = fullChunks(contract.documents);
  assert.equal(specs.length, 497);
  assert.equal(specs[0].id, '000000');
  assert.equal(specs.at(-1).id, '000496');
  assert.equal(specs.at(-1).entries.length, 88);
  assert.deepEqual(fullChunks(contract.documents).map(spec => spec.sha256),
    specs.map(spec => spec.sha256));
  const dry = await main(['--mode', 'full', '--manifest', manifestPath]);
  assert.equal(dry.mode, 'DRY_RUN_OFFLINE');
  assert.equal(dry.productionWrites, 0);
  assert.equal(dry.total, 49688);

  const directory = mkdtempSync(join(tmpdir(), 'osm-full-contract-'));
  try {
    const secondPath = join(directory, 'manifest.json');
    const second = buildFullManifest(seed, secondPath);
    assert.equal(second.sha256, contract.manifestSha256);
    assert.deepEqual(readFileSync(secondPath), readFileSync(manifestPath));
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});

test('root and largest chunk metadata have ample Firestore document margin', () => {
  const contract = validateFullManifest(manifestPath, seed);
  const specs = fullChunks(contract.documents);
  const rootBytes = Buffer.byteLength(JSON.stringify(rootMetadata(contract,
    { creates: 48936, identical: 752 }, specs.length)));
  const sizes = specs.map(spec => Buffer.byteLength(JSON.stringify(
    chunkMetadata(spec, spec.entries))));
  const maxChunkBytes = Math.max(...sizes);
  assert.ok(rootBytes < 10000);
  assert.ok(maxChunkBytes < 20000);
  console.log(JSON.stringify({ rootBytes, maxChunkBytes }));
});

test('wrong mode, hash, seed, project and native target fail before Firebase access', async () => {
  const contract = validateFullManifest(manifestPath, seed);
  const base = ['--mode', 'full', '--manifest', manifestPath, '--execute',
    '--confirm-full-import', '--project', 'vendingnavi',
    '--confirm-project', 'vendingnavi', '--run-id', contract.manifest.runId,
    '--approved-manifest-sha', contract.manifestSha256,
    '--approved-seed-sha', contract.manifest.seedSha256];
  await assert.rejects(main(base.filter((value, index) =>
    value !== '--confirm-full-import')), /confirm-full-import/);
  await assert.rejects(main(base.map(value => value === 'full' ? 'pilot' : value)),
    /explicit --mode full/);
  await assert.rejects(main(base.map(value => value === 'vendingnavi' ? 'wrong-project' : value)),
    /Production target/);
  await assert.rejects(main([...base, '--collection', 'vending_machines']),
    /unknown or incomplete option/);
  await assert.rejects(main(base.map(value =>
    value === contract.manifestSha256 ? 'bad' : value)), /manifest SHA mismatch/);
  await assert.rejects(main(base.map(value =>
    value === contract.manifest.seedSha256 ? 'bad' : value)), /seed SHA required/);

  const directory = mkdtempSync(join(tmpdir(), 'osm-full-negative-'));
  try {
    const copy = structuredClone(contract.manifest);
    copy.collections.points = 'vending_machines';
    const path = join(directory, 'native.json');
    writeFileSync(path, JSON.stringify(copy));
    assert.throws(() => validateFullManifest(path, seed), /collection allowlist mismatch/);
    copy.collections.points = 'osm_vending_seed';
    copy.points[1] = copy.points[0];
    writeFileSync(path, JSON.stringify(copy));
    assert.throws(() => validateFullManifest(path, seed), /point ID\/order mismatch/);
    const wrongSeed = join(directory, 'osm_vending_seed_jp.ndjson.gz');
    writeFileSync(wrongSeed, 'bad seed');
    assert.throws(() => validateFullManifest(manifestPath, wrongSeed),
      /canonical seed SHA mismatch/);
    assert.notEqual(sha256(readFileSync(path)), contract.manifestSha256);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
