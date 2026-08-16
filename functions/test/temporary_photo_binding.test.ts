import {strict as assert} from "node:assert";
import {test} from "node:test";

import {
  buildTemporaryPhotoBinding,
} from "../src/photo_recognition/temporary_photo_binding";
import type {
  TemporaryPhotoContent,
} from "../src/photo_recognition/temporary_photo_content_adapter";

function photo(bytes: readonly number[]): TemporaryPhotoContent {
  return {
    objectPath:
      "machine_uploads/user-1/123e4567-e89b-42d3-a456-426614174000/original.jpg",
    contentType: "image/jpeg",
    bytes: Buffer.from(bytes),
  };
}

test("photo binding is deterministic for the exact recognized bytes", () => {
  const first = buildTemporaryPhotoBinding(
    photo([0xff, 0xd8, 0xff, 0xd9]),
  );
  const second = buildTemporaryPhotoBinding(
    photo([0xff, 0xd8, 0xff, 0xd9]),
  );

  assert.deepEqual(first, second);
  assert.match(first.contentSha256, /^[0-9a-f]{64}$/);
  assert.equal(first.sizeBytes, 4);
});

test("photo binding changes when temporary image bytes change", () => {
  const first = buildTemporaryPhotoBinding(
    photo([0xff, 0xd8, 0xff, 0xd9]),
  );
  const second = buildTemporaryPhotoBinding(
    photo([0xff, 0xd8, 0x00, 0xff, 0xd9]),
  );

  assert.notEqual(first.contentSha256, second.contentSha256);
});
