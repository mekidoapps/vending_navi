import {GoogleGenAI} from "@google/genai";

import type {
  RecognitionProvider,
  RecognitionProviderInput,
  RecognitionProviderOutput,
} from "./recognition_provider";
import {
  RecognitionProviderFailure,
} from "./recognition_provider";

export const VERTEX_RECOGNITION_PROVIDER_KEY =
  "vertex_gemini_3_5_flash_lite";
export const VERTEX_RECOGNITION_MODEL =
  "gemini-3.5-flash-lite";
export const VERTEX_RECOGNITION_LOCATION = "global";

interface VertexTextGeneratorInput {
  readonly model: string;
  readonly prompt: string;
  readonly imageBase64: string;
  readonly mimeType: "image/jpeg";
}

export interface VertexTextGenerator {
  generate(input: VertexTextGeneratorInput): Promise<string | undefined>;
}

interface RawRecognitionOutput {
  readonly machineManufacturerLabels: readonly string[];
  readonly productLabels: readonly string[];
  readonly unresolvedLabels: readonly string[];
}

const MAX_MANUFACTURER_LABELS = 3;
const MAX_PRODUCT_LABELS = 40;
const MAX_UNRESOLVED_LABELS = 40;
const MAX_LABEL_LENGTH = 120;

export class VertexRecognitionProvider implements RecognitionProvider {
  readonly providerKey = VERTEX_RECOGNITION_PROVIDER_KEY;

  constructor(
    private readonly generator: VertexTextGenerator,
  ) {}

  async recognize(
    input: RecognitionProviderInput,
  ): Promise<RecognitionProviderOutput> {
    try {
      const text = await this.generator.generate({
        model: VERTEX_RECOGNITION_MODEL,
        prompt: VERTEX_RECOGNITION_PROMPT,
        imageBase64: input.imageBytes.toString("base64"),
        mimeType: input.mimeType,
      });

      return parseVertexRecognitionOutput(text);
    } catch (error: unknown) {
      if (error instanceof RecognitionProviderFailure) {
        throw error;
      }

      throw new RecognitionProviderFailure(
        "Vertex photo recognition failed.",
      );
    }
  }
}

export function createProductionVertexRecognitionProvider(
  projectId = resolveGoogleCloudProjectId(process.env),
): VertexRecognitionProvider {
  const normalizedProjectId = projectId.trim();
  if (normalizedProjectId.length === 0) {
    throw new RecognitionProviderFailure(
      "Google Cloud project ID is not configured.",
    );
  }

  const ai = new GoogleGenAI({
    enterprise: true,
    project: normalizedProjectId,
    location: VERTEX_RECOGNITION_LOCATION,
    apiVersion: "v1",
  });

  const generator: VertexTextGenerator = {
    async generate(input) {
      const response = await ai.models.generateContent({
        model: input.model,
        contents: [
          {
            role: "user",
            parts: [
              {text: input.prompt},
              {
                inlineData: {
                  data: input.imageBase64,
                  mimeType: input.mimeType,
                },
              },
            ],
          },
        ],
        config: {
          responseMimeType: "application/json",
          responseJsonSchema: VERTEX_RECOGNITION_RESPONSE_JSON_SCHEMA,
        },
      });

      return response.text;
    },
  };

  return new VertexRecognitionProvider(generator);
}

export function resolveGoogleCloudProjectId(
  env: NodeJS.ProcessEnv,
): string {
  const candidates = [
    env.GCLOUD_PROJECT,
    env.GOOGLE_CLOUD_PROJECT,
  ];

  for (const candidate of candidates) {
    if (
      typeof candidate === "string" &&
      candidate.trim().length > 0
    ) {
      return candidate.trim();
    }
  }

  return "";
}

export function parseVertexRecognitionOutput(
  rawText: string | undefined,
): RecognitionProviderOutput {
  if (typeof rawText !== "string" || rawText.trim().length === 0) {
    throw new RecognitionProviderFailure(
      "Vertex recognition returned an empty response.",
    );
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(rawText);
  } catch {
    throw new RecognitionProviderFailure(
      "Vertex recognition returned invalid JSON.",
    );
  }

  if (
    typeof parsed !== "object" ||
    parsed === null ||
    Array.isArray(parsed)
  ) {
    throw new RecognitionProviderFailure(
      "Vertex recognition returned an invalid object.",
    );
  }

  const record = parsed as Record<string, unknown>;
  const allowedKeys = new Set([
    "machineManufacturerLabels",
    "productLabels",
    "unresolvedLabels",
  ]);

  for (const key of Object.keys(record)) {
    if (!allowedKeys.has(key)) {
      throw new RecognitionProviderFailure(
        "Vertex recognition returned an unexpected field.",
      );
    }
  }

  const output: RawRecognitionOutput = {
    machineManufacturerLabels: parseLabelArray(
      record.machineManufacturerLabels,
      "machineManufacturerLabels",
      MAX_MANUFACTURER_LABELS,
    ),
    productLabels: parseLabelArray(
      record.productLabels,
      "productLabels",
      MAX_PRODUCT_LABELS,
    ),
    unresolvedLabels: parseLabelArray(
      record.unresolvedLabels,
      "unresolvedLabels",
      MAX_UNRESOLVED_LABELS,
    ),
  };

  return output;
}

function parseLabelArray(
  value: unknown,
  fieldName: string,
  maxItems: number,
): readonly string[] {
  if (!Array.isArray(value)) {
    throw new RecognitionProviderFailure(
      `Vertex recognition ${fieldName} must be an array.`,
    );
  }

  if (value.length > maxItems) {
    throw new RecognitionProviderFailure(
      `Vertex recognition ${fieldName} exceeds the item limit.`,
    );
  }

  const result: string[] = [];
  const seen = new Set<string>();

  for (const item of value) {
    if (typeof item !== "string") {
      throw new RecognitionProviderFailure(
        `Vertex recognition ${fieldName} must contain strings.`,
      );
    }

    const normalized = item.trim();
    if (
      normalized.length === 0 ||
      normalized.length > MAX_LABEL_LENGTH
    ) {
      throw new RecognitionProviderFailure(
        `Vertex recognition ${fieldName} contains an invalid label.`,
      );
    }

    if (!seen.has(normalized)) {
      seen.add(normalized);
      result.push(normalized);
    }
  }

  return result;
}

export const VERTEX_RECOGNITION_RESPONSE_JSON_SCHEMA = {
  type: "object",
  properties: {
    machineManufacturerLabels: {
      type: "array",
      description:
        "Manufacturer/company labels supported by branding on the vending " +
        "machine body or header itself. Do not include beverage product " +
        "brands merely because they appear on cans or bottles.",
      items: {type: "string"},
      maxItems: MAX_MANUFACTURER_LABELS,
    },
    productLabels: {
      type: "array",
      description:
        "Specific beverage product names visibly supported by package text " +
        "or design. Preserve the visible language/script whenever readable. " +
        "Do not translate or romanize Japanese labels.",
      items: {type: "string"},
      maxItems: MAX_PRODUCT_LABELS,
    },
    unresolvedLabels: {
      type: "array",
      description:
        "Visible manufacturer/product clues that cannot safely be resolved " +
        "to a specific full label. Preserve visible text where possible " +
        "instead of guessing.",
      items: {type: "string"},
      maxItems: MAX_UNRESOLVED_LABELS,
    },
  },
  required: [
    "machineManufacturerLabels",
    "productLabels",
    "unresolvedLabels",
  ],
  additionalProperties: false,
} as const;

export const VERTEX_RECOGNITION_PROMPT = `
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
- If the machine-level manufacturer cannot be determined, return an empty array.

2. productLabels
- Extract SPECIFIC beverage product names from visible cans/bottles.
- Preserve the original visible language/script whenever readable.
- Japanese text should remain Japanese.
- Do NOT translate Japanese product names into English.
- Do NOT romanize Japanese product names.
- Do NOT invent a likely product from the manufacturer or package color.
- Do NOT add products that are not visibly supported.
- If only a partial or ambiguous clue is visible, put it in unresolvedLabels
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
