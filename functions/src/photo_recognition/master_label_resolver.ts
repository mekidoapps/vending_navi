export interface MasterLabelRecord {
  readonly id: string;
  readonly name: string;
  readonly searchKeywords: readonly string[];
  readonly isActive: boolean;
}

export interface MasterLabelResolution {
  readonly resolvedIds: readonly string[];
  readonly unresolvedLabels: readonly string[];
}

const DASH_VARIANTS = /[‐‒–—―−]/g;
const WAVE_VARIANTS = /[〜∼∾~]/g;
const WHITESPACE = /\s+/g;

/**
 * Normalize only representation differences that are safe for master lookup.
 *
 * Deliberately NOT performed:
 * - fuzzy / edit-distance matching
 * - partial matching
 * - transliteration between Latin and Japanese product names
 * - synonym guessing
 *
 * Those cases must be covered by explicit master searchKeywords or remain
 * unresolved for user confirmation.
 */
export function normalizeMasterLabel(input: string): string {
  let value = input.normalize("NFKC").trim().toLowerCase();
  if (value.length === 0) {
    return "";
  }

  value = toKatakana(value)
    .replace(WAVE_VARIANTS, "～")
    .replace(DASH_VARIANTS, "-")
    .replace(WHITESPACE, " ")
    .trim();

  value = value
    .replace(/\s*・\s*/g, "・")
    .replace(/\s*\/\s*/g, "/")
    .replace(/\s*-\s*/g, "-");

  return value;
}

export function resolveMasterLabels(
  labels: readonly string[],
  records: readonly MasterLabelRecord[],
): MasterLabelResolution {
  const lookup = buildLookup(records);
  const resolvedIds: string[] = [];
  const unresolvedLabels: string[] = [];
  const seenResolvedIds = new Set<string>();
  const seenUnresolvedLabels = new Set<string>();

  for (const rawLabel of labels) {
    const displayLabel = rawLabel.trim();
    const normalizedLabel = normalizeMasterLabel(rawLabel);

    if (normalizedLabel.length === 0) {
      continue;
    }

    const candidateIds = lookup.get(normalizedLabel);
    if (candidateIds !== undefined && candidateIds.size === 1) {
      const [resolvedId] = candidateIds;
      if (!seenResolvedIds.has(resolvedId)) {
        seenResolvedIds.add(resolvedId);
        resolvedIds.push(resolvedId);
      }
      continue;
    }

    if (!seenUnresolvedLabels.has(displayLabel)) {
      seenUnresolvedLabels.add(displayLabel);
      unresolvedLabels.push(displayLabel);
    }
  }

  return {
    resolvedIds,
    unresolvedLabels,
  };
}

function buildLookup(
  records: readonly MasterLabelRecord[],
): Map<string, Set<string>> {
  const lookup = new Map<string, Set<string>>();

  for (const record of records) {
    if (!record.isActive) {
      continue;
    }

    const labels = [record.name, ...record.searchKeywords];

    for (const label of labels) {
      const normalizedLabel = normalizeMasterLabel(label);
      if (normalizedLabel.length === 0) {
        continue;
      }

      const ids = lookup.get(normalizedLabel) ?? new Set<string>();
      ids.add(record.id);
      lookup.set(normalizedLabel, ids);
    }
  }

  return lookup;
}

function toKatakana(input: string): string {
  let result = "";

  for (const character of input) {
    const codePoint = character.codePointAt(0);
    if (
      codePoint !== undefined &&
      codePoint >= 0x3041 &&
      codePoint <= 0x3096
    ) {
      result += String.fromCodePoint(codePoint + 0x60);
    } else {
      result += character;
    }
  }

  return result;
}
