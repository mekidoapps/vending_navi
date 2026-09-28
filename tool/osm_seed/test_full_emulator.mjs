// Full canonical 49,688-entry test. Firestore emulator + demo project only.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { main as pilotMain } from './pilot_import.mjs';
import { validateManifest } from './pilot_contract.mjs';
import { main as fullMain } from './full_import.mjs';
import { validateFullManifest } from './full_contract.mjs';

const project = process.env.GCLOUD_PROJECT;
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!project?.startsWith('demo-') ||
    !/^(127\.0\.0\.1|localhost):\d+$/.test(host ?? '')) {
  throw new Error('Refusing non-demo or non-loopback Firestore target');
}
const requireFunctions = createRequire(new URL('../../functions/package.json', import.meta.url));
const { initializeApp, deleteApp } = requireFunctions('firebase-admin/app');
const { getFirestore } = requireFunctions('firebase-admin/firestore');
const app = initializeApp({ projectId: project }, 'osm-full-emulator-test');
const db = getFirestore(app);
const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const seed = resolve(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');
const pilotPath = resolve(root, 'outputs/osm_seed/2026-09-26/osm_pilot_20260927_01.manifest.json');
const fullPath = resolve(root, 'outputs/osm_seed/2026-09-26/osm_full_20260928_01.manifest.json');
const pilot = validateManifest(pilotPath, seed);
const full = validateFullManifest(fullPath, seed);
const pilotArgs = ['--pilot-manifest', pilotPath, '--seed', seed,
  '--project', project, '--confirm-project', project,
  '--run-id', pilot.manifest.runId, '--manifest-sha256', pilot.manifestSha256,
  '--emulator', '--execute'];
const fullArgs = ['--mode', 'full', '--manifest', fullPath, '--seed', seed,
  '--project', project, '--confirm-project', project, '--run-id', full.manifest.runId,
  '--approved-manifest-sha', full.manifestSha256,
  '--approved-seed-sha', full.manifest.seedSha256, '--emulator'];
const execute = [...fullArgs, '--execute', '--confirm-full-import'];
const runRef = db.collection('osm_import_runs').doc(full.manifest.runId);
async function count(name) {
  return (await db.collection(name).count().get()).data().count;
}

try {
  await db.collection('vending_machines').doc('native-untouched').create({ status: 'active' });
  await db.collection('users').doc('user-untouched').create({ value: true });
  const pilotResult = await pilotMain(pilotArgs);
  assert.equal(pilotResult.createdPoints, 346);
  assert.equal(pilotResult.createdAggregates, 406);
  assert.equal(await count('osm_vending_seed'), 346);
  assert.equal(await count('osm_vending_aggregate'), 406);
  const pilotFirst = await db.doc(`osm_vending_seed/${pilot.manifest.points[0].id}`).get();

  const plan = await fullMain([...fullArgs, '--read-only-preflight']);
  assert.equal(plan.identical, 752);
  assert.equal(plan.creates, 48936);
  assert.equal(plan.conflicts, 0);
  assert.equal(plan.productionWrites, 0);

  await assert.rejects(fullMain([...execute,
    '--simulate-failure-after-chunks', '127']), /simulated full import failure/);
  assert.equal((await runRef.get()).data().status, 'PARTIAL');
  assert.equal((await runRef.collection('chunks').get()).size, 127);
  assert.equal((await runRef.collection('chunks').doc('000127').get()).exists, false);
  assert.equal((await runRef.get()).data().createdPaths, undefined);

  const resumed = await fullMain(execute);
  assert.equal(resumed.status, 'COMPLETED');
  assert.equal(resumed.createdPoints, 40788 - 346);
  assert.equal(resumed.createdAggregates, 8900 - 406);
  assert.equal(resumed.skipped, 752);
  assert.equal(resumed.duplicateCreates, 0);
  assert.equal(await count('osm_vending_seed'), 40788);
  assert.equal(await count('osm_vending_aggregate'), 8900);
  assert.equal((await runRef.collection('chunks').get()).size, 497);

  const second = await fullMain(execute);
  assert.equal(second.createdPoints, 40442);
  assert.equal(second.createdAggregates, 8494);
  assert.equal(await count('osm_vending_seed'), 40788);
  assert.equal(await count('osm_vending_aggregate'), 8900);

  const dry = await fullMain([...fullArgs, '--rollback']);
  assert.equal(dry.owned, 48936);
  assert.equal(dry.remaining, 48936);
  assert.equal(dry.pendingChunks, 497);
  assert.equal(await count('osm_vending_seed'), 40788);

  await assert.rejects(fullMain([...fullArgs, '--rollback', '--execute',
    '--confirm-full-rollback', '--simulate-rollback-failure-after-chunks', '100']),
  /simulated full rollback failure/);
  assert.equal((await runRef.get()).data().rollbackStatus, 'PARTIAL');
  assert.equal((await runRef.collection('chunks').where('status', '==', 'ROLLED_BACK').get()).size,
    100);
  const finish = await fullMain([...fullArgs, '--rollback', '--execute',
    '--confirm-full-rollback']);
  assert.equal(finish.status, 'ROLLED_BACK');
  assert.equal(await count('osm_vending_seed'), 346);
  assert.equal(await count('osm_vending_aggregate'), 406);
  assert.equal((await runRef.get()).data().rollbackStatus, 'DONE');
  assert.equal((await runRef.collection('chunks').get()).size, 497);
  assert.deepEqual((await db.doc(pilotFirst.ref.path).get()).data(), pilotFirst.data());
  assert.equal((await db.collection('osm_import_runs').doc(pilot.manifest.runId).get()).data().status,
    'COMPLETED');
  assert.equal((await db.collection('vending_machines').doc('native-untouched').get()).exists,
    true);
  assert.equal((await db.collection('users').doc('user-untouched').get()).exists, true);

  const conflict = full.documents.find(doc => !pilot.manifest.points.some(p => p.id === doc.id) &&
    doc.collection === 'osm_vending_seed');
  await db.doc(conflict.path).create({ status: 'published', source: 'different-data' });
  await assert.rejects(fullMain(execute), /conflict before first write/);
  assert.equal((await runRef.get()).data().status, 'ROLLED_BACK');
  await db.doc(conflict.path).delete();
  const unrelated = db.doc('osm_vending_seed/osm:node:9999999999');
  await unrelated.create({ status: 'published', source: 'another-run' });
  await assert.rejects(fullMain([...fullArgs, '--read-only-preflight']),
    /unexpected OSM documents outside full manifest/);
  assert.equal((await runRef.get()).data().status, 'ROLLED_BACK');
  console.log('OSM full-scale import/resume/idempotency/rollback/conflict PASS');
} finally {
  await deleteApp(app);
}
