// Firestore emulator only. Refuses to run without a demo project and host.
import assert from 'node:assert/strict';

const project = process.env.GCLOUD_PROJECT;
const host = process.env.FIRESTORE_EMULATOR_HOST;
if (!project?.startsWith('demo-') || !host || !/^(127\.0\.0\.1|localhost):\d+$/.test(host)) {
  throw new Error('Refusing non-emulator or non-demo Firestore target');
}
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;

async function request(path, { method = 'GET', body, owner = false } = {}) {
  return fetch(`${base}${path}`, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(owner ? { authorization: 'Bearer owner' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
}

function string(value) { return { stringValue: value }; }
function integer(value) { return { integerValue: String(value) }; }
async function seed(collection, id, status, aggregate = false) {
  const fields = { status: string(status), geohash: string('xn76ur') };
  if (aggregate) fields.precision = integer(6);
  const response = await request(`/${collection}/${id}`, {
    method: 'PATCH', owner: true, body: { fields },
  });
  assert.equal(response.status, 200, `emulator seed ${collection}: ${await response.text()}`);
}

function rangeFilter(collection, limit, aggregate = false) {
  const filters = [
    { fieldFilter: { field: { fieldPath: 'status' }, op: 'EQUAL', value: string('published') } },
    { fieldFilter: { field: { fieldPath: 'geohash' }, op: 'GREATER_THAN_OR_EQUAL', value: string('xn76') } },
    { fieldFilter: { field: { fieldPath: 'geohash' }, op: 'LESS_THAN_OR_EQUAL', value: string('xn76\uf8ff') } },
  ];
  if (aggregate) filters.push({ fieldFilter: { field: { fieldPath: 'precision' }, op: 'EQUAL', value: integer(6) } });
  return {
    structuredQuery: {
      from: [{ collectionId: collection }],
      where: { compositeFilter: { op: 'AND', filters } },
      ...(limit === null ? {} : { limit }),
    },
  };
}

await seed('osm_vending_seed', 'osm:node:1', 'published');
await seed('osm_vending_seed', 'osm:node:2', 'candidate_not_imported');
await seed('osm_vending_aggregate', 'p6_xn76ur', 'published', true);
await seed('osm_vending_aggregate', 'p6_xn76us', 'candidate_not_imported', true);

assert.equal((await request('/osm_vending_seed/osm:node:1')).status, 200);
assert.equal((await request('/osm_vending_seed/osm:node:2')).status, 403);
assert.equal((await request('/osm_vending_aggregate/p6_xn76ur')).status, 200);
assert.equal((await request('/osm_vending_aggregate/p6_xn76us')).status, 403);

for (const [collection, cap, aggregate] of [
  ['osm_vending_seed', 121, false],
  ['osm_vending_aggregate', 81, true],
]) {
  assert.equal((await request(':runQuery', {
    method: 'POST', body: rangeFilter(collection, cap, aggregate),
  })).status, 200);
  assert.equal((await request(':runQuery', {
    method: 'POST', body: rangeFilter(collection, cap + 1, aggregate),
  })).status, 403);
  assert.equal((await request(':runQuery', {
    method: 'POST', body: rangeFilter(collection, null, aggregate),
  })).status, 403);
  assert.equal((await request(`/${collection}/client_write`, {
    method: 'PATCH', body: { fields: { status: string('published') } },
  })).status, 403);
}
console.log('OSM Firestore emulator read caps / status / write denial PASS');
