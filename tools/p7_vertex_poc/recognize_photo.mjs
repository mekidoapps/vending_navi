import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { GoogleGenAI } from '@google/genai';

const PROJECT = process.env.GOOGLE_CLOUD_PROJECT || 'vendingnavi';
const LOCATION = process.env.GOOGLE_CLOUD_LOCATION || 'global';
const MODEL = process.env.VENDING_POC_MODEL || 'gemini-3.5-flash-lite';
const MAX_BYTES = 5 * 1024 * 1024;

function fail(message) {
  console.error(`ERROR: ${message}`);
  process.exit(1);
}

const imageArg = process.argv[2];
if (!imageArg) {
  fail('Usage: npm run recognize -- "C:/path/to/vending_machine.jpg"');
}

const imagePath = path.resolve(imageArg);
if (!fs.existsSync(imagePath)) {
  fail(`Image not found: ${imagePath}`);
}

const stat = fs.statSync(imagePath);
if (!stat.isFile()) {
  fail(`Not a file: ${imagePath}`);
}
if (stat.size <= 0) {
  fail('Image is empty.');
}
if (stat.size > MAX_BYTES) {
  fail(
    `Image is ${(stat.size / 1024 / 1024).toFixed(2)} MiB; ` +
      'P7 contract limit is 5 MiB.'
  );
}

const extension = path.extname(imagePath).toLowerCase();
if (!['.jpg', '.jpeg'].includes(extension)) {
  fail(
    'P7-03 PoC accepts JPEG only. Convert the test image to .jpg/.jpeg first.'
  );
}

const imageBase64 = fs.readFileSync(imagePath).toString('base64');

const responseJsonSchema = {
  type: 'object',
  properties: {
    machineManufacturerLabels: {
      type: 'array',
      description:
        'Manufacturer/company labels supported by branding on the vending machine body or header itself. Do not include beverage product brands merely because they appear on cans or bottles.',
      items: { type: 'string' },
      maxItems: 3
    },
    productLabels: {
      type: 'array',
      description:
        'Specific beverage product names visibly supported by package text/design. Preserve the language/script visible in the image whenever readable. Do not translate or romanize Japanese labels.',
      items: { type: 'string' },
      maxItems: 40
    },
    unresolvedLabels: {
      type: 'array',
      description:
        'Visible manufacturer/product clues that cannot safely be resolved to a specific full label. Preserve visible text where possible instead of guessing.',
      items: { type: 'string' },
      maxItems: 40
    },
    notes: {
      type: 'array',
      description:
        'Short observations only about image quality or recognition ambiguity. Never include personal data.',
      items: { type: 'string' },
      maxItems: 10
    }
  },
  required: [
    'machineManufacturerLabels',
    'productLabels',
    'unresolvedLabels',
    'notes'
  ],
  additionalProperties: false
};

const prompt = `
You are analyzing one vending-machine photo for the VendingNavi app.

Your job is ONLY to extract candidate labels that are visibly supported by the
photo. These candidates will later be matched to a controlled Manufacturer
Master and Product Master, and a human user will confirm them before anything
is published.

Definitions:

1. machineManufacturerLabels
- Identify the company/manufacturer branding of the VENDING MACHINE ITSELF.
- Use logos or text on the machine body, header, large central panel, or other
  machine-level branding.
- Do NOT put a beverage brand here merely because it appears on a bottle/can.
- Examples of things that belong here: machine-level "Asahi", "Coca-Cola",
  "SUNTORY", etc., when actually visible on the vending machine.
- If the machine-level manufacturer cannot be determined, return an empty array.

2. productLabels
- Extract SPECIFIC beverage product names from the visible cans/bottles.
- Preserve the original visible language/script whenever readable.
- Japanese text should remain Japanese.
- Do NOT translate Japanese product names into English.
- Do NOT romanize Japanese product names.
- Do NOT invent a likely product from the manufacturer or package color.
- Do NOT add products that are not visibly supported.
- Prefer a useful full product name when clearly readable.
- If only a partial/ambiguous clue is visible, put it in unresolvedLabels
  instead of guessing.

3. unresolvedLabels
- Put partial text, ambiguous package clues, or labels that are visible but not
  safe enough to identify as a specific manufacturer/product.
- It is better to leave something unresolved than to guess.

General rules:
- It is acceptable for any array to be empty.
- Deduplicate repeated identical products.
- Do not output shelf positions or prices.
- Do not identify or describe people.
- Do not output QR-code contents, addresses, GPS data, or other personal data.
- Do not infer the machine manufacturer from the products alone if machine-level
  branding is not visible.
- Output only the requested structured JSON.
`.trim();

console.log('P7-03 Vertex AI photo PoC - prompt v2');
console.log(`project=${PROJECT}`);
console.log(`location=${LOCATION}`);
console.log(`model=${MODEL}`);
console.log(
  `image=${path.basename(imagePath)} (${(stat.size / 1024).toFixed(1)} KiB)`
);
console.log('');

const ai = new GoogleGenAI({
  vertexai: true,
  project: PROJECT,
  location: LOCATION,
  apiVersion: 'v1'
});

try {
  const response = await ai.models.generateContent({
    model: MODEL,
    contents: [
      {
        role: 'user',
        parts: [
          { text: prompt },
          {
            inlineData: {
              data: imageBase64,
              mimeType: 'image/jpeg'
            }
          }
        ]
      }
    ],
    config: {
      responseMimeType: 'application/json',
      responseJsonSchema
    }
  });

  const text = response.text;
  if (!text || !text.trim()) {
    fail('Model returned no text.');
  }

  let parsed;
  try {
    parsed = JSON.parse(text);
  } catch {
    console.error('Raw response:');
    console.error(text);
    fail('Structured response was not valid JSON.');
  }

  console.log('=== NORMALIZED POC RESPONSE ===');
  console.log(JSON.stringify(parsed, null, 2));
  console.log('=== END ===');
} catch (error) {
  console.error('Vertex AI request failed.');
  if (error && typeof error === 'object') {
    if ('name' in error) console.error(`name: ${error.name}`);
    if ('status' in error) console.error(`status: ${error.status}`);
    if ('message' in error) console.error(`message: ${error.message}`);
  } else {
    console.error(String(error));
  }
  process.exit(1);
}
