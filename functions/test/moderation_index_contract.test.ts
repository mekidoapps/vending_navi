import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

type IndexField = {readonly fieldPath: string; readonly order: string};
type CompositeIndex = {
  readonly collectionGroup: string;
  readonly queryScope: string;
  readonly fields: readonly IndexField[];
};

const queueSources = ["machine_reports", "machine_corrections"] as const;

function hasQueueIndex(index: CompositeIndex, collectionGroup: string): boolean {
  return index.collectionGroup === collectionGroup &&
    index.queryScope === "COLLECTION" &&
    JSON.stringify(index.fields) === JSON.stringify([
      {fieldPath: "status", order: "ASCENDING"},
      {fieldPath: "createdAt", order: "ASCENDING"},
    ]);
}

test("moderation queue queries and composite indexes stay aligned", () => {
  const source = readFileSync("src/moderation_read.ts", "utf8");
  const config = JSON.parse(
    readFileSync("../firebase/v2/firestore.indexes.json", "utf8"),
  ) as {indexes?: readonly CompositeIndex[]};
  const indexes = config.indexes ?? [];

  for (const collection of queueSources) {
    assert.match(
      source,
      new RegExp(
        `collection\\("${collection}"\\)\\.where\\("status", "in", ` +
          `\\["new", "inReview", "resolutionPending"\\]\\)` +
          `\\.orderBy\\("createdAt", "asc"\\)`,
      ),
    );
    assert.ok(
      indexes.some((index) => hasQueueIndex(index, collection)),
      `${collection} queue query requires status ASC, createdAt ASC`,
    );
  }
});
