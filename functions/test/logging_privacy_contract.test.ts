import assert from "node:assert/strict";
import {
  readdirSync,
  readFileSync,
} from "node:fs";
import {join} from "node:path";
import test from "node:test";

function collectTypeScriptFiles(directory: string): string[] {
  const result: string[] = [];

  for (const entry of readdirSync(directory, {
    withFileTypes: true,
  })) {
    const path = join(directory, entry.name);

    if (entry.isDirectory()) {
      result.push(...collectTypeScriptFiles(path));
      continue;
    }

    if (entry.isFile() && entry.name.endsWith(".ts")) {
      result.push(path);
    }
  }

  return result;
}

test("Functions source contains only approved structured console logging", () => {
  const files = collectTypeScriptFiles("src");

  const consoleCalls: Array<{
    readonly path: string;
    readonly kind: string;
  }> = [];

  for (const path of files) {
    const source = readFileSync(path, "utf8");

    for (
      const match of source.matchAll(
        /console\.(log|info|warn|error|debug)\s*\(/g,
      )
    ) {
      consoleCalls.push({
        path,
        kind: match[1],
      });
    }
  }

  assert.equal(
    consoleCalls.length,
    6,
    "Unexpected console logging was added to Functions source.",
  );

  for (const call of consoleCalls) {
    assert.equal(
      call.path.replaceAll("\\", "/"),
      "src/index.ts",
      `Console logging must stay in Callable wrappers: ${call.path}`,
    );

    assert.equal(
      call.kind,
      "error",
      "Only structured failure logging is currently approved.",
    );
  }
});

test("Callable failure logs do not contain sensitive or raw payload fields", () => {
  const source = readFileSync("src/index.ts", "utf8");

  const blocks =
    source.match(
      /console\.error\([\s\S]*?\n\s*\}\);/g,
    ) ?? [];

  assert.equal(
    blocks.length,
    6,
    "Expected six approved structured failure logs for content mutation Callables.",
  );

  const forbiddenPatterns: Array<readonly [RegExp, string]> = [
    [/request\.data/, "raw request data"],
    [/\brawInput\b/, "raw input"],
    [/error\.message/, "unknown exception message"],
    [/error\.stack/, "exception stack"],
    [/JSON\.stringify/, "serialized payload/error"],
    [/\bauthorization\b/i, "authorization header"],
    [/\bidToken\b/i, "ID token"],
    [/\baccessToken\b/i, "access token"],
    [/\bappCheck\b/i, "App Check token/data"],
    [/\bemail\b/i, "email address"],
    [/\bimageBytes\b/, "image bytes"],
    [/\bphoto\.bytes\b/, "photo bytes"],
    [/\bstoragePath\b/, "Storage path"],
    [/\bdownloadURL\b/i, "download URL"],
    [/\blatitude\b/, "latitude"],
    [/\blongitude\b/, "longitude"],
    [/\bplaceDescription\b/, "place description"],
    [/\bmessage\s*:/, "free-form message"],
  ];

  for (const block of blocks) {
    for (const [pattern, description] of forbiddenPatterns) {
      assert.doesNotMatch(
        block,
        pattern,
        `Callable log must not contain ${description}.`,
      );
    }
  }
});


test(
  "deleteAccount does not add identity-bearing failure logs",
  () => {
    const source =
      readFileSync(
        "src/index.ts",
        "utf8",
      );

    const marker =
      "export const deleteAccount = onCall(";

    const index =
      source.indexOf(marker);

    assert.notEqual(
      index,
      -1,
      "deleteAccount Callable must exist.",
    );

    const block =
      source.slice(index);

    assert.doesNotMatch(
      block,
      /console\.(log|info|warn|error|debug)\s*\(/,
      "Account deletion must not log user identity or deletion payload.",
    );
  },
);
