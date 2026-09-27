import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import test from 'node:test';

import { main } from './pilot_import.mjs';
import { COLLECTIONS, validateManifest } from './pilot_contract.mjs';

const root = resolve(import.meta.dirname, '../..');
const seed = join(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');
const manifest = join(root, 'outputs/osm_seed/2026-09-26/osm_pilot_20260927_01.manifest.json');

test('real pilot is 346 + 406, bounded, public-minimal and offline by default', async () => {
  const plan = await main(['--pilot-manifest', manifest, '--seed', seed]);
  assert.equal(plan.mode, 'DRY_RUN_OFFLINE');
  assert.equal(plan.points, 346);
  assert.equal(plan.aggregates, 406);
  assert.equal(plan.total, 752);
  assert.equal(plan.productionWrites, 0);
  assert.deepEqual(plan.collections, COLLECTIONS);
  const content = readFileSync(manifest, 'utf8');
  assert.ok(!content.includes('rawTags'));
  assert.ok(!content.includes('importRunId'));
  assert.ok(!content.includes('osm_vending_cells'));
});

test('negative gates refuse before Firebase initialization or writes', async () => {
  const { manifest: content, manifestSha256 } = validateManifest(manifest, seed);
  const base = ['--pilot-manifest', manifest, '--seed', seed,
    '--execute', '--run-id', content.runId, '--manifest-sha256', manifestSha256];
  await assert.rejects(main([...base, '--project', 'wrong-project',
    '--confirm-project', 'wrong-project']), /Production target/);
  await assert.rejects(main([...base, '--project', 'vendingnavi',
    '--confirm-project', 'vendingnavi', '--collection', 'vending_machines']),
  /unknown or incomplete option/);
  await assert.rejects(main(['--pilot-manifest', manifest,
    '--manifest-sha256', 'bad']), /manifest SHA mismatch/);
  const directory = mkdtempSync(join(tmpdir(), 'osm-pilot-contract-'));
  try {
    const write = (name, value) => {
      const path = join(directory, name);
      writeFileSync(path, JSON.stringify(value));
      return path;
    };
    const over = structuredClone(content);
    while (over.points.length + over.aggregates.length <= 900) {
      over.points.push(structuredClone(over.points[0]));
    }
    over.expectedPoints = over.points.length;
    over.expectedTotal = over.points.length + over.aggregates.length;
    assert.throws(() => validateManifest(write('over.json', over), seed), /hard cap/);
    const invalid = structuredClone(content);
    invalid.points[0].id = 'not-an-osm-id';
    invalid.points[0].data.sourceId = 'not-an-osm-id';
    assert.throws(() => validateManifest(write('invalid.json', invalid), seed), /invalid Tier-A point/);
    const nonTierA = structuredClone(content);
    nonTierA.points[0].data.confidence = 'tier_B';
    assert.throws(() => validateManifest(write('non-tier-a.json', nonTierA), seed),
      /invalid Tier-A point/);
    const badSeed = join(directory, 'bad-seed.gz');
    writeFileSync(badSeed, 'bad');
    assert.throws(() => validateManifest(manifest, badSeed), /canonical seed SHA mismatch/);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
});
