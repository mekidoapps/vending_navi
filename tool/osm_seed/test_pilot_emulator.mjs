// Firestore emulator only. Exercises partial failure, resume, idempotency and run-owned rollback.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { main } from './pilot_import.mjs';
import { sha256, validateManifest } from './pilot_contract.mjs';

const project = process.env.GCLOUD_PROJECT;
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!project?.startsWith('demo-') || !/^(127\.0\.0\.1|localhost):\d+$/.test(host ?? '')) {
  throw new Error('Refusing non-demo or non-loopback Firestore target');
}
const requireFunctions = createRequire(new URL('../../functions/package.json', import.meta.url));
const { initializeApp, deleteApp } = requireFunctions('firebase-admin/app');
const { getFirestore } = requireFunctions('firebase-admin/firestore');
const app = initializeApp({ projectId: project }, 'osm-pilot-emulator-test');
const db = getFirestore(app);
const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const seed = resolve(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');
const manifest = resolve(root, 'outputs/osm_seed/2026-09-26/osm_pilot_20260927_01.manifest.json');
const contract = validateManifest(manifest, seed);
const args = ['--pilot-manifest', manifest, '--seed', seed,
  '--project', project, '--confirm-project', project,
  '--run-id', contract.manifest.runId, '--manifest-sha256', contract.manifestSha256,
  '--emulator'];
const execute = [...args, '--execute'];

try {
  assert.equal((await db.collection('osm_vending_seed').get()).size, 0);
  assert.equal((await db.collection('osm_vending_aggregate').get()).size, 0);
  await db.collection('vending_machines').doc('untouched-native').create({ status: 'active' });
  await db.collection('osm_vending_seed').doc('osm:node:9999999999').create({
    status: 'published', source: 'another-run',
  });

  await assert.rejects(main([...execute, '--simulate-failure-after-batches', '1']),
    /simulated partial failure/);
  const runRef = db.collection('osm_import_runs').doc(contract.manifest.runId);
  let run = (await runRef.get()).data();
  assert.equal(run.status, 'PARTIAL');
  assert.equal(run.createdPaths.length, 100);

  const resumed = await main(execute);
  assert.equal(resumed.status, 'COMPLETED');
  assert.equal(resumed.createdPoints, 346);
  assert.equal(resumed.createdAggregates, 406);
  assert.equal((await db.collection('osm_vending_seed').get()).size, 347);
  assert.equal((await db.collection('osm_vending_aggregate').get()).size, 406);

  const second = await main(execute);
  assert.equal(second.createdPoints, 346);
  assert.equal(second.createdAggregates, 406);
  run = (await runRef.get()).data();
  assert.equal(new Set(run.createdPaths).size, 752);

  const dry = await main([...args, '--rollback']);
  assert.equal(dry.dryRun, true);
  assert.equal(dry.remaining, 752);
  assert.equal(dry.nativeAffected, 0);
  assert.equal((await db.collection('osm_vending_seed').get()).size, 347);

  const rollback = await main([...execute, '--rollback']);
  assert.equal(rollback.status, 'ROLLED_BACK');
  assert.equal(rollback.deleted, 752);
  assert.equal((await db.collection('osm_vending_seed').get()).size, 1);
  assert.equal((await db.collection('osm_vending_aggregate').get()).size, 0);
  assert.equal((await db.collection('vending_machines').doc('untouched-native').get()).exists, true);
  assert.equal((await db.collection('osm_vending_seed').doc('osm:node:9999999999').get()).exists, true);
  assert.equal((await runRef.get()).data().status, 'ROLLED_BACK');

  const directory = mkdtempSync(join(tmpdir(), 'osm-pilot-emulator-'));
  try {
    const alternate = JSON.parse(readFileSync(manifest, 'utf8'));
    alternate.runId = 'osm-pilot-20260927-02';
    const alternatePath = join(directory, 'alternate.json');
    const alternateBytes = JSON.stringify(alternate);
    writeFileSync(alternatePath, alternateBytes);
    const alternateArgs = args.flatMap((value, i) => {
      if (value === manifest) return [alternatePath];
      if (value === contract.manifest.runId) return [alternate.runId];
      if (value === contract.manifestSha256) return [sha256(alternateBytes)];
      return [value];
    });
    const conflictRef = db.doc(`osm_vending_seed/${alternate.points[0].id}`);
    await conflictRef.create({ status: 'published', source: 'different-data' });
    await assert.rejects(main([...alternateArgs, '--execute']), /conflict before first write/);
    assert.equal((await db.collection('osm_import_runs').doc(alternate.runId).get()).exists, false);
    assert.equal((await db.collection('osm_vending_seed').get()).size, 2);
    await conflictRef.delete();

    // Identical data that predates a run may be skipped, never acquired as
    // rollback ownership. The other-run OSM document also remains intact.
    await conflictRef.create(alternate.points[0].data);
    const imported = await main([...alternateArgs, '--execute']);
    assert.equal(imported.createdPoints, 345);
    assert.equal(imported.createdAggregates, 406);
    assert.equal(imported.skipped, 1);
    const rolledBack = await main([...alternateArgs, '--execute', '--rollback']);
    assert.equal(rolledBack.deleted, 751);
    assert.equal((await conflictRef.get()).exists, true);
    assert.equal((await db.collection('osm_vending_seed').doc('osm:node:9999999999').get()).exists, true);
    assert.equal((await db.collection('vending_machines').doc('untouched-native').get()).exists, true);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
  console.log('OSM pilot emulator import/resume/idempotency/rollback PASS');
} finally {
  await deleteApp(app);
}
