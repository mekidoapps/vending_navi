#!/usr/bin/env node
/** Full OSM importer. Offline by default; only explicit, hash-locked modes touch Firestore. */
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { BATCH_SIZE, COLLECTIONS, SEED_SHA, stable } from './pilot_contract.mjs';
import { fullChunks, validateFullManifest } from './full_contract.mjs';

const requireFunctions = createRequire(new URL('../../functions/package.json', import.meta.url));
const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const defaultSeed = resolve(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');
const TOOL_VERSION = 'osm-full-sharded-v1';
const PILOT_RUN_ID = 'osm-pilot-20260927-01';
const PILOT_MANIFEST_SHA = '8a79a98a270d81a476776cfaa7dc26a7d1ebc0951139862486b0062ce1122cb0';

function parse(argv) {
  const flags = new Set(['--execute', '--rollback', '--read-only-preflight',
    '--emulator', '--confirm-full-import', '--confirm-full-rollback']);
  const values = new Set(['--mode', '--manifest', '--seed', '--project', '--run-id',
    '--approved-manifest-sha', '--approved-seed-sha', '--confirm-project',
    '--simulate-failure-after-chunks', '--simulate-rollback-failure-after-chunks']);
  const options = {};
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (flags.has(key)) options[key.slice(2)] = true;
    else if (values.has(key) && argv[i + 1] && !argv[i + 1].startsWith('--')) {
      options[key.slice(2)] = argv[++i];
    } else throw new Error(`unknown or incomplete option: ${key}`);
  }
  if (options.mode !== 'full' || !options.manifest) {
    throw new Error('explicit --mode full and --manifest required');
  }
  if (options.rollback && options['read-only-preflight']) {
    throw new Error('rollback and read-only preflight are mutually exclusive');
  }
  if (options.execute && !options.rollback && !options['confirm-full-import']) {
    throw new Error('--confirm-full-import required for full execute');
  }
  if (options.execute && options.rollback && !options['confirm-full-rollback']) {
    throw new Error('--confirm-full-rollback required for rollback execute');
  }
  return options;
}

function requireTarget(options, contract) {
  const project = options.project;
  if (!project || options['confirm-project'] !== project ||
      options['run-id'] !== contract.manifest.runId ||
      options['approved-manifest-sha']?.toLowerCase() !== contract.manifestSha256 ||
      options['approved-seed-sha']?.toLowerCase() !== SEED_SHA) {
    throw new Error('matching project, run ID, manifest SHA and seed SHA required');
  }
  if (options.emulator) {
    if (!project.startsWith('demo-') ||
        !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) {
      throw new Error('demo project and loopback Firestore emulator required');
    }
  } else if (project !== 'vendingnavi' || process.env.FIRESTORE_EMULATOR_HOST ||
      [process.env.GCLOUD_PROJECT, process.env.GOOGLE_CLOUD_PROJECT]
        .some(value => value && value !== project)) {
    throw new Error('Production target must be vendingnavi without emulator or conflicting project');
  }
  if ((options['simulate-failure-after-chunks'] ||
       options['simulate-rollback-failure-after-chunks']) && !options.emulator) {
    throw new Error('failure injection is emulator-only');
  }
  return project;
}

function firestore(project) {
  const { initializeApp, getApps } = requireFunctions('firebase-admin/app');
  const { getFirestore } = requireFunctions('firebase-admin/firestore');
  const app = getApps().find(candidate => candidate.options.projectId === project) ??
    initializeApp({ projectId: project }, `osm-full-${project}`);
  return getFirestore(app);
}

export async function preflight(db, documents) {
  const state = new Map();
  let identical = 0;
  let existingPoints = 0;
  let existingAggregates = 0;
  for (let start = 0; start < documents.length; start += BATCH_SIZE) {
    const batch = documents.slice(start, start + BATCH_SIZE);
    const snapshots = await db.getAll(...batch.map(doc => db.doc(doc.path)));
    for (let i = 0; i < batch.length; i++) {
      const snapshot = snapshots[i];
      if (snapshot.exists) {
        if (stable(snapshot.data()) !== stable(batch[i].data)) {
          throw new Error(`conflict before first write: ${batch[i].path}`);
        }
        identical++;
        if (batch[i].collection === COLLECTIONS.points) existingPoints++;
        else existingAggregates++;
      }
      state.set(batch[i].path, snapshot.exists);
    }
  }
  const [pointCount, aggregateCount] = await Promise.all([
    db.collection(COLLECTIONS.points).count().get(),
    db.collection(COLLECTIONS.aggregates).count().get(),
  ]);
  if (pointCount.data().count !== existingPoints ||
      aggregateCount.data().count !== existingAggregates) {
    throw new Error('unexpected OSM documents outside full manifest');
  }
  return { identical, creates: documents.length - identical, state,
    existingPoints, existingAggregates };
}

async function protectedPilotPaths(db, documents, state) {
  const snapshot = await db.collection(COLLECTIONS.runs).doc(PILOT_RUN_ID).get();
  const pilot = snapshot.data();
  if (!pilot || pilot.mode !== 'pilot' || pilot.status !== 'COMPLETED' ||
      pilot.seedSha256 !== SEED_SHA || pilot.manifestSha256 !== PILOT_MANIFEST_SHA ||
      pilot.createdPoints !== 346 || pilot.createdAggregates !== 406 ||
      !Array.isArray(pilot.createdPaths) || pilot.createdPaths.length !== 752) {
    throw new Error('canonical Production pilot ownership missing or changed');
  }
  const all = new Set(documents.map(doc => doc.path));
  const owned = new Set(pilot.createdPaths);
  if (owned.size !== 752 || [...owned].some(path => !all.has(path) ||
      (state && !state.get(path)))) {
    throw new Error('pilot-owned public document missing from full canonical state');
  }
  if (!state) {
    const byPath = new Map(documents.map(doc => [doc.path, doc]));
    const paths = [...owned];
    for (let start = 0; start < paths.length; start += BATCH_SIZE) {
      const batch = paths.slice(start, start + BATCH_SIZE);
      const snapshots = await db.getAll(...batch.map(path => db.doc(path)));
      snapshots.forEach((item, index) => {
        if (!item.exists || stable(item.data()) !== stable(byPath.get(batch[index]).data)) {
          throw new Error(`pilot-owned document missing or changed: ${batch[index]}`);
        }
      });
    }
  }
  return owned;
}

export function rootMetadata(contract, plan, chunkCount) {
  return {
    runId: contract.manifest.runId, mode: 'full',
    sourceSnapshot: contract.manifest.sourceSnapshot,
    seedSha256: contract.manifest.seedSha256,
    manifestSha256: contract.manifestSha256,
    plannedPoints: contract.manifest.expectedPoints,
    plannedAggregates: contract.manifest.expectedAggregates,
    plannedTotal: contract.manifest.expectedTotal,
    expectedCreates: plan.creates, expectedSkips: plan.identical,
    chunkSize: BATCH_SIZE, chunkCount, toolVersion: TOOL_VERSION,
    status: 'IMPORTING', rollbackStatus: 'NOT_STARTED',
    startedAt: new Date().toISOString(), completedAt: null,
  };
}

export function chunkMetadata(spec, creates) {
  const created = new Set(creates.map(doc => doc.path));
  const createdPointIds = spec.entries.filter(doc =>
    doc.collection === COLLECTIONS.points && created.has(doc.path)).map(doc => doc.id);
  const createdAggregateIds = spec.entries.filter(doc =>
    doc.collection === COLLECTIONS.aggregates && created.has(doc.path)).map(doc => doc.id);
  return {
    index: spec.index, manifestStart: spec.start,
    manifestEndExclusive: spec.endExclusive,
    manifestChunkSha256: spec.sha256, plannedCount: spec.entries.length,
    createCount: creates.length, skipCount: spec.entries.length - creates.length,
    createdPointIds, createdAggregateIds,
    status: 'COMPLETED', committedAt: new Date().toISOString(), rolledBackAt: null,
  };
}

function verifyRoot(data, contract, chunkCount) {
  if (!data || data.runId !== contract.manifest.runId || data.mode !== 'full' ||
      data.manifestSha256 !== contract.manifestSha256 ||
      data.seedSha256 !== contract.manifest.seedSha256 ||
      data.plannedTotal !== contract.documents.length ||
      data.chunkSize !== BATCH_SIZE || data.chunkCount !== chunkCount ||
      data.rollbackStatus !== 'NOT_STARTED' || data.status === 'ROLLED_BACK') {
    throw new Error('run root identity/state mismatch');
  }
  if (!['IMPORTING', 'PARTIAL', 'FAILED', 'COMPLETED'].includes(data.status)) {
    throw new Error('unsupported full run state');
  }
}

function verifyChunk(data, spec, state, allowRolledBack = false) {
  if (!data || data.index !== spec.index || data.manifestStart !== spec.start ||
      data.manifestEndExclusive !== spec.endExclusive ||
      data.manifestChunkSha256 !== spec.sha256 ||
      data.plannedCount !== spec.entries.length ||
      !Array.isArray(data.createdPointIds) || !Array.isArray(data.createdAggregateIds)) {
    throw new Error(`chunk identity mismatch: ${spec.id}`);
  }
  if (data.status !== 'COMPLETED' && !(allowRolledBack && data.status === 'ROLLED_BACK')) {
    throw new Error(`unsupported chunk state: ${spec.id}`);
  }
  const owned = [
    ...data.createdPointIds.map(id => `${COLLECTIONS.points}/${id}`),
    ...data.createdAggregateIds.map(id => `${COLLECTIONS.aggregates}/${id}`),
  ];
  const expected = new Set(spec.entries.map(doc => doc.path));
  if (new Set(owned).size !== owned.length || owned.some(path => !expected.has(path)) ||
      data.createCount !== owned.length || data.skipCount !== spec.entries.length - owned.length) {
    throw new Error(`invalid chunk ownership: ${spec.id}`);
  }
  if (state && data.status === 'COMPLETED' && spec.entries.some(doc => !state.get(doc.path))) {
    throw new Error(`completed chunk document missing: ${spec.id}`);
  }
  return owned;
}

async function readChunks(runRef, specs) {
  const snapshots = await runRef.collection('chunks').get();
  const byId = new Map(specs.map(spec => [spec.id, spec]));
  const result = new Map();
  for (const snapshot of snapshots.docs) {
    if (!byId.has(snapshot.id)) throw new Error(`unexpected chunk: ${snapshot.id}`);
    result.set(snapshot.id, snapshot);
  }
  return result;
}

async function importFull(db, contract, specs, options) {
  // A complete comparison happens before even the run root is created.
  const plan = await preflight(db, contract.documents);
  const pilotOwned = await protectedPilotPaths(db, contract.documents, plan.state);
  const runRef = db.collection(COLLECTIONS.runs).doc(contract.manifest.runId);
  const existing = await runRef.get();
  if (existing.exists) verifyRoot(existing.data(), contract, specs.length);
  const completed = existing.exists ? await readChunks(runRef, specs) : new Map();
  for (const spec of specs) {
    const chunk = completed.get(spec.id);
    if (chunk && verifyChunk(chunk.data(), spec, plan.state)
      .some(path => pilotOwned.has(path))) {
      throw new Error(`full run claims pilot-owned document: ${spec.id}`);
    }
  }
  if (!existing.exists) await runRef.create(rootMetadata(contract, plan, specs.length));
  let committed = 0;
  try {
    for (const spec of specs) {
      if (completed.has(spec.id)) continue;
      const creates = spec.entries.filter(doc => !plan.state.get(doc.path));
      const batch = db.batch();
      for (const doc of creates) batch.create(db.doc(doc.path), doc.data);
      batch.create(runRef.collection('chunks').doc(spec.id), chunkMetadata(spec, creates));
      await batch.commit();
      committed++;
      if (options['simulate-failure-after-chunks'] &&
          committed >= Number(options['simulate-failure-after-chunks'])) {
        throw new Error('emulator-only simulated full import failure');
      }
    }
    const chunks = await readChunks(runRef, specs);
    let createdPoints = 0, createdAggregates = 0, skipped = 0;
    for (const spec of specs) {
      const chunk = chunks.get(spec.id);
      if (!chunk) throw new Error(`missing committed chunk: ${spec.id}`);
      const data = chunk.data();
      verifyChunk(data, spec);
      createdPoints += data.createdPointIds.length;
      createdAggregates += data.createdAggregateIds.length;
      skipped += data.skipCount;
    }
    await runRef.update({ status: 'COMPLETED', completedAt: new Date().toISOString(),
      createdPoints, createdAggregates, skipped });
    return { status: 'COMPLETED', planned: contract.documents.length,
      createdPoints, createdAggregates, skipped, chunks: specs.length,
      duplicateCreates: 0, nativeWrites: 0 };
  } catch (error) {
    const chunks = await readChunks(runRef, specs);
    await runRef.update({ status: chunks.size ? 'PARTIAL' : 'FAILED',
      lastErrorAt: new Date().toISOString() });
    throw error;
  }
}

async function rollbackFull(db, contract, specs, execute, options) {
  const pilotOwned = await protectedPilotPaths(db, contract.documents);
  const runRef = db.collection(COLLECTIONS.runs).doc(contract.manifest.runId);
  const rootSnapshot = await runRef.get();
  if (!rootSnapshot.exists) throw new Error('full run not found');
  const run = rootSnapshot.data();
  if (run.runId !== contract.manifest.runId || run.mode !== 'full' ||
      run.manifestSha256 !== contract.manifestSha256 ||
      run.seedSha256 !== contract.manifest.seedSha256 ||
      run.chunkCount !== specs.length ||
      !['PARTIAL', 'FAILED', 'COMPLETED', 'ROLLED_BACK'].includes(run.status)) {
    throw new Error('rollback run identity/state mismatch');
  }
  const chunks = await readChunks(runRef, specs);
  const pending = [];
  let owned = 0;
  for (const spec of [...specs].reverse()) {
    const snapshot = chunks.get(spec.id);
    if (!snapshot) continue;
    const paths = verifyChunk(snapshot.data(), spec, null, true);
    if (paths.some(path => pilotOwned.has(path))) {
      throw new Error(`rollback claims pilot-owned document: ${spec.id}`);
    }
    owned += paths.length;
    if (snapshot.data().status === 'COMPLETED') {
      pending.push({ spec, snapshot, paths });
    } else if (paths.length) {
      const snapshots = await db.getAll(...paths.map(path => db.doc(path)));
      if (snapshots.some(item => item.exists)) {
        throw new Error(`rolled-back chunk has reappearing owned document: ${spec.id}`);
      }
    }
  }
  // Verify every pending owned document before the first delete.
  for (const item of pending) {
    const known = new Map(item.spec.entries.map(doc => [doc.path, doc]));
    const snapshots = item.paths.length ?
      await db.getAll(...item.paths.map(path => db.doc(path))) : [];
    item.ownedSnapshots = snapshots;
    snapshots.forEach((snapshot, index) => {
      const path = item.paths[index];
      if (!snapshot.exists || stable(snapshot.data()) !== stable(known.get(path).data)) {
        throw new Error(`rollback conflict or missing owned document: ${path}`);
      }
    });
  }
  const remaining = pending.reduce((sum, item) => sum + item.paths.length, 0);
  if (run.status === 'ROLLED_BACK' && remaining) {
    throw new Error('rolled-back run has pending owned chunks');
  }
  if (!execute) return { mode: 'DRY_RUN', runId: contract.manifest.runId,
    owned, remaining, pendingChunks: pending.length, nativeDeletes: 0 };
  if (run.status === 'ROLLED_BACK') return { status: 'ROLLED_BACK', deleted: 0 };
  await runRef.update({ rollbackStatus: 'IN_PROGRESS' });
  let deleted = 0, committed = 0;
  try {
    for (const item of pending) {
      const batch = db.batch();
      item.paths.forEach((path, index) => batch.delete(db.doc(path),
        { lastUpdateTime: item.ownedSnapshots[index].updateTime }));
      batch.update(item.snapshot.ref,
        { status: 'ROLLED_BACK', rolledBackAt: new Date().toISOString() },
        { lastUpdateTime: item.snapshot.updateTime });
      await batch.commit();
      deleted += item.paths.length;
      committed++;
      if (options['simulate-rollback-failure-after-chunks'] &&
          committed >= Number(options['simulate-rollback-failure-after-chunks'])) {
        throw new Error('emulator-only simulated full rollback failure');
      }
    }
    await runRef.update({ status: 'ROLLED_BACK', rollbackStatus: 'DONE',
      rollbackCompletedAt: new Date().toISOString() });
    return { status: 'ROLLED_BACK', deleted, owned, nativeDeletes: 0 };
  } catch (error) {
    await runRef.update({ rollbackStatus: 'PARTIAL' });
    throw error;
  }
}

export async function main(argv = process.argv.slice(2)) {
  const options = parse(argv);
  const contract = validateFullManifest(resolve(options.manifest),
    resolve(options.seed ?? defaultSeed), options['approved-manifest-sha']);
  const specs = fullChunks(contract.documents);
  if (options['run-id'] && options['run-id'] !== contract.manifest.runId) {
    throw new Error('run ID mismatch');
  }
  if (!options.execute && !options.rollback && !options['read-only-preflight']) {
    return { mode: 'DRY_RUN_OFFLINE', runId: contract.manifest.runId,
      manifestSha256: contract.manifestSha256, seedSha256: SEED_SHA,
      points: contract.manifest.expectedPoints,
      aggregates: contract.manifest.expectedAggregates,
      total: contract.documents.length, chunks: specs.length,
      productionWrites: 0, collections: COLLECTIONS };
  }
  const project = requireTarget(options, contract);
  const db = firestore(project);
  if (options['read-only-preflight']) {
    const plan = await preflight(db, contract.documents);
    const pilotOwned = await protectedPilotPaths(db, contract.documents, plan.state);
    return { mode: 'READ_ONLY_PREFLIGHT', project, runId: contract.manifest.runId,
      identical: plan.identical, creates: plan.creates, conflicts: 0,
      existingPoints: plan.existingPoints,
      existingAggregates: plan.existingAggregates,
      pilotProtected: pilotOwned.size, total: contract.documents.length,
      productionWrites: 0 };
  }
  if (options.rollback) return rollbackFull(db, contract, specs, !!options.execute, options);
  return importFull(db, contract, specs, options);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().then(result => console.log(JSON.stringify(result, null, 2)))
    .catch(error => { console.error(`OSM full refused: ${error.message}`); process.exitCode = 1; });
}
