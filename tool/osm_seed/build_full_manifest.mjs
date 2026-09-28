#!/usr/bin/env node
/** Deterministic, ID-only execution manifest for the locked canonical OSM seed. */
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { sha256 } from './pilot_contract.mjs';
import { canonicalFullDocuments, fullManifest, FULL_RUN_ID } from './full_contract.mjs';

const root = resolve(fileURLToPath(new URL('../..', import.meta.url)));
const seed = resolve(root, 'outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz');
const output = resolve(root, 'outputs/osm_seed/2026-09-26/osm_full_20260928_01.manifest.json');

export function buildFullManifest(seedPath = seed, outputPath = output,
  runId = FULL_RUN_ID) {
  const manifest = fullManifest(canonicalFullDocuments(seedPath), runId);
  // No line ending: Windows core.autocrlf must not change an approved SHA.
  const bytes = Buffer.from(JSON.stringify(manifest), 'utf8');
  mkdirSync(dirname(outputPath), { recursive: true });
  writeFileSync(outputPath, bytes);
  if (sha256(readFileSync(outputPath)) !== sha256(bytes)) {
    throw new Error('manifest readback SHA mismatch');
  }
  return { path: outputPath, sha256: sha256(bytes), bytes: bytes.length,
    points: manifest.expectedPoints, aggregates: manifest.expectedAggregates,
    total: manifest.expectedTotal, runId: manifest.runId };
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 2) throw new Error('no CLI overrides; canonical output only');
  console.log(JSON.stringify(buildFullManifest(), null, 2));
}
