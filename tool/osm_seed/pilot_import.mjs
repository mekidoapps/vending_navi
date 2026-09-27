#!/usr/bin/env node
/** Pilot-only, explicit-gate Firestore importer. No Firebase client is loaded for default dry-run. */
import { createRequire } from 'node:module';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { BATCH_SIZE, CAP, COLLECTIONS, stable, validateManifest } from './pilot_contract.mjs';

const requireFunctions = createRequire(new URL('../../functions/package.json', import.meta.url));
const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const defaultSeed = resolve(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');

function parse(argv) {
  const flags = new Set(['--execute', '--rollback', '--emulator']);
  const values = new Set(['--pilot-manifest', '--seed', '--project', '--run-id',
    '--manifest-sha256', '--confirm-project', '--simulate-failure-after-batches']);
  const options = {};
  for (let index = 0; index < argv.length; index++) {
    const key = argv[index];
    if (flags.has(key)) options[key.slice(2)] = true;
    else if (values.has(key) && argv[index + 1] && !argv[index + 1].startsWith('--')) {
      options[key.slice(2)] = argv[++index];
    } else throw new Error(`unknown or incomplete option: ${key}`);
  }
  if (!options['pilot-manifest']) throw new Error('--pilot-manifest is required');
  return options;
}

function chunks(items, size = BATCH_SIZE) {
  const result = [];
  for (let i = 0; i < items.length; i += size) result.push(items.slice(i, i + size));
  return result;
}

function requireTarget(options, manifest) {
  const project = options.project;
  if (!project || options['confirm-project'] !== project || options['run-id'] !== manifest.runId ||
      !options['manifest-sha256']) {
    throw new Error('project, matching confirmation, run ID and approved manifest SHA required');
  }
  if (options.emulator) {
    if (!project.startsWith('demo-') ||
        !/^(127\.0\.0\.1|localhost):\d+$/.test(process.env.FIRESTORE_EMULATOR_HOST ?? '')) {
      throw new Error('demo project and loopback Firestore emulator required');
    }
  } else if (project !== 'vendingnavi' || process.env.FIRESTORE_EMULATOR_HOST ||
      [process.env.GCLOUD_PROJECT, process.env.GOOGLE_CLOUD_PROJECT]
        .some(value => value && value !== project)) {
    throw new Error('Production target must be vendingnavi without emulator or conflicting project environment');
  }
  if (options['simulate-failure-after-batches'] && !options.emulator) {
    throw new Error('failure simulation is emulator-only');
  }
  return project;
}

function firestore(project) {
  const { initializeApp, getApps } = requireFunctions('firebase-admin/app');
  const { getFirestore } = requireFunctions('firebase-admin/firestore');
  const app = getApps().find(candidate => candidate.options.projectId === project) ??
    initializeApp({ projectId: project }, `osm-pilot-${project}`);
  return getFirestore(app);
}

async function readTargetDocs(db, documents) {
  const result = new Map();
  for (const batch of chunks(documents)) {
    const snapshots = await db.getAll(...batch.map(doc => db.doc(doc.path)));
    snapshots.forEach((snapshot, i) => result.set(batch[i].path, snapshot));
  }
  return result;
}

async function preflight(db, documents) {
  const existing = await readTargetDocs(db, documents);
  let identical = 0;
  for (const doc of documents) {
    const snapshot = existing.get(doc.path);
    if (!snapshot.exists) continue;
    if (stable(snapshot.data()) !== stable(doc.data)) {
      throw new Error(`conflict before first write: ${doc.path}`);
    }
    identical++;
  }
  return { identical, missing: documents.length - identical };
}

function initialRun(manifest, manifestSha256) {
  return {
    runId: manifest.runId, mode: 'pilot', sourceSnapshot: manifest.sourceSnapshot,
    seedSha256: manifest.seedSha256, manifestSha256,
    plannedPoints: manifest.expectedPoints, plannedAggregates: manifest.expectedAggregates,
    createdPoints: 0, createdAggregates: 0, skipped: 0, errors: 0,
    status: 'IMPORTING', startedAt: new Date().toISOString(), completedAt: null,
    rollbackStatus: 'NOT_STARTED', createdPaths: [], skippedPaths: [], rolledBackPaths: [],
    pointSourceIds: manifest.points.map(item => item.id),
    aggregateIds: manifest.aggregates.map(item => item.id),
  };
}

async function importPilot(db, contract, options) {
  const { manifest, manifestSha256, documents } = contract;
  const runRef = db.collection(COLLECTIONS.runs).doc(manifest.runId);
  const before = await preflight(db, documents);
  let run = await runRef.get();
  if (run.exists) {
    const data = run.data();
    if (data.manifestSha256 !== manifestSha256 || data.seedSha256 !== manifest.seedSha256 ||
        data.runId !== manifest.runId || data.status === 'ROLLED_BACK' ||
        data.rollbackStatus !== 'NOT_STARTED') {
      throw new Error('run ID belongs to a different, rolled-back or rolling-back import');
    }
    if (!['IMPORTING', 'PARTIAL', 'FAILED', 'COMPLETED'].includes(data.status)) {
      throw new Error('unsupported run state');
    }
  } else {
    // Atomic create prevents a second process from taking ownership of this ID.
    await runRef.create(initialRun(manifest, manifestSha256));
  }
  let completedBatches = 0;
  try {
    for (const batch of chunks(documents)) {
      await db.runTransaction(async transaction => {
        const runSnapshot = await transaction.get(runRef);
        const current = runSnapshot.data();
        if (!current || current.manifestSha256 !== manifestSha256 ||
            current.rollbackStatus !== 'NOT_STARTED') throw new Error('run changed during import');
        const refs = batch.map(doc => db.doc(doc.path));
        const snapshots = await transaction.getAll(...refs);
        const created = new Set(current.createdPaths ?? []);
        const skippedPaths = new Set(current.skippedPaths ?? []);
        let createdPoints = current.createdPoints ?? 0;
        let createdAggregates = current.createdAggregates ?? 0;
        let skipped = current.skipped ?? 0;
        batch.forEach((doc, i) => {
          const snapshot = snapshots[i];
          if (snapshot.exists) {
            if (stable(snapshot.data()) !== stable(doc.data)) throw new Error(`conflict: ${doc.path}`);
            if (!created.has(doc.path) && !skippedPaths.has(doc.path)) {
              skippedPaths.add(doc.path);
              skipped++;
            }
          } else {
            transaction.create(refs[i], doc.data);
            created.add(doc.path);
            if (doc.collection === COLLECTIONS.points) createdPoints++;
            else createdAggregates++;
          }
        });
        transaction.update(runRef, {
          createdPaths: [...created].sort(), skippedPaths: [...skippedPaths].sort(),
          createdPoints, createdAggregates,
          skipped, status: 'IMPORTING', errors: current.errors ?? 0,
        });
      });
      completedBatches++;
      if (options['simulate-failure-after-batches'] &&
          completedBatches >= Number(options['simulate-failure-after-batches'])) {
        throw new Error('emulator-only simulated partial failure');
      }
    }
    await runRef.update({ status: 'COMPLETED', completedAt: new Date().toISOString() });
    run = await runRef.get();
    const data = run.data();
    return { planned: documents.length, createdPoints: data.createdPoints,
      createdAggregates: data.createdAggregates, skipped: data.skipped,
      preflightIdentical: before.identical, errors: data.errors, status: data.status };
  } catch (error) {
    const snapshot = await runRef.get();
    if (snapshot.exists) {
      const data = snapshot.data();
      await runRef.update({ status: (data.createdPaths ?? []).length ? 'PARTIAL' : 'FAILED',
        errors: (data.errors ?? 0) + 1 });
    }
    throw error;
  }
}

async function rollbackPilot(db, contract, execute) {
  const { manifest, manifestSha256, documents } = contract;
  const runRef = db.collection(COLLECTIONS.runs).doc(manifest.runId);
  const run = await runRef.get();
  if (!run.exists) throw new Error('run not found');
  const data = run.data();
  if (data.manifestSha256 !== manifestSha256 || data.runId !== manifest.runId ||
      data.seedSha256 !== manifest.seedSha256) throw new Error('run manifest mismatch');
  if (data.status === 'IMPORTING') throw new Error('cannot rollback an active import');
  const known = new Map(documents.map(doc => [doc.path, doc]));
  const owned = data.createdPaths ?? [];
  const already = new Set(data.rolledBackPaths ?? []);
  if (owned.length > CAP || owned.some(path => !known.has(path))) {
    throw new Error('run owns an invalid or out-of-scope path');
  }
  const remaining = owned.filter(path => !already.has(path));
  const docs = await readTargetDocs(db, remaining.map(path => known.get(path)));
  for (const path of remaining) {
    const snapshot = docs.get(path);
    if (snapshot.exists && stable(snapshot.data()) !== stable(known.get(path).data)) {
      throw new Error(`rollback conflict: ${path}`);
    }
  }
  if (!execute) return { dryRun: true, runId: manifest.runId,
    owned: owned.length, remaining: remaining.length, nativeAffected: 0 };
  if (data.status === 'ROLLED_BACK') return { status: 'ROLLED_BACK', deleted: 0 };
  await runRef.update({ rollbackStatus: 'IN_PROGRESS' });
  let deleted = 0;
  try {
    for (const batch of chunks(remaining)) {
      const batchDeleted = await db.runTransaction(async transaction => {
        const runSnapshot = await transaction.get(runRef);
        const current = runSnapshot.data();
        if (!current || current.manifestSha256 !== manifestSha256 ||
            current.rollbackStatus !== 'IN_PROGRESS') throw new Error('run changed during rollback');
        const refs = batch.map(path => db.doc(path));
        const snapshots = await transaction.getAll(...refs);
        let inThisBatch = 0;
        snapshots.forEach((snapshot, i) => {
          if (snapshot.exists) {
            if (stable(snapshot.data()) !== stable(known.get(batch[i]).data))
              throw new Error(`rollback conflict: ${batch[i]}`);
            transaction.delete(refs[i]);
            inThisBatch++;
          }
        });
        transaction.update(runRef, { rolledBackPaths:
          [...new Set([...(current.rolledBackPaths ?? []), ...batch])].sort() });
        return inThisBatch;
      });
      deleted += batchDeleted;
    }
    await runRef.update({ rollbackStatus: 'DONE', status: 'ROLLED_BACK',
      rollbackCompletedAt: new Date().toISOString() });
    return { status: 'ROLLED_BACK', deleted, nativeAffected: 0 };
  } catch (error) {
    await runRef.update({ rollbackStatus: 'PARTIAL' });
    throw error;
  }
}

export async function main(argv = process.argv.slice(2)) {
  const options = parse(argv);
  const contract = validateManifest(resolve(options['pilot-manifest']),
    resolve(options.seed ?? defaultSeed), options['manifest-sha256']);
  if (contract.documents.length > CAP) throw new Error('pilot hard cap exceeded');
  if (options['run-id'] && options['run-id'] !== contract.manifest.runId)
    throw new Error('run ID mismatch');
  if (!options.execute && !options.rollback) {
    return { mode: 'DRY_RUN_OFFLINE', runId: contract.manifest.runId,
      manifestSha256: contract.manifestSha256,
      points: contract.manifest.expectedPoints,
      aggregates: contract.manifest.expectedAggregates,
      total: contract.documents.length, productionWrites: 0,
      collections: COLLECTIONS };
  }
  requireTarget(options, contract.manifest);
  const db = firestore(options.project);
  if (options.rollback) return rollbackPilot(db, contract, !!options.execute);
  return importPilot(db, contract, options);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().then(result => console.log(JSON.stringify(result, null, 2)))
    .catch(error => { console.error(`OSM pilot refused: ${error.message}`); process.exitCode = 1; });
}
