"""Offline, read-only import dry run. No Firebase client or write code exists here."""

from __future__ import annotations

import argparse
import gzip
import json
import re
from collections import Counter
from pathlib import Path

SOURCE_ID = re.compile(r"^osm:(node|way|relation):[1-9][0-9]*$")
FORBIDDEN_FIELDS = {"products", "prices", "inventory", "photos", "createdBy"}


def plan(seed: Path, batch_size: int = 400) -> dict:
    if not 1 <= batch_size <= 400:
        raise ValueError("batch size must be between 1 and 400")
    seen = set()
    counts = Counter()
    with gzip.open(seed, "rt", encoding="utf-8") as source:
        for line_number, line in enumerate(source, start=1):
            record = json.loads(line)
            source_id = record.get("sourceId", "")
            if not SOURCE_ID.fullmatch(source_id):
                raise ValueError(f"line {line_number}: invalid source ID")
            if source_id in seen:
                raise ValueError(f"line {line_number}: duplicate source ID")
            seen.add(source_id)
            if record.get("source") != "OpenStreetMap" or record.get("license") != "ODbL-1.0":
                raise ValueError(f"line {line_number}: invalid source/license")
            if record.get("confidence") != "tier_A_explicit_drinks":
                raise ValueError(f"line {line_number}: non-Tier-A candidate")
            if not -90 <= record["latitude"] <= 90 or not -180 <= record["longitude"] <= 180:
                raise ValueError(f"line {line_number}: invalid coordinates")
            if FORBIDDEN_FIELDS & record.keys():
                raise ValueError(f"line {line_number}: inferred product/user field")
            counts["validated"] += 1
    return {
        "dry_run": True,
        "destination_proposal": "osm_vending_seed/{sourceId}",
        "validated": counts["validated"],
        "planned_batches": (counts["validated"] + batch_size - 1) // batch_size,
        "batch_size": batch_size,
        "production_writes": 0,
        "idempotent_key": "sourceId",
        "existing_id_skip_count": "UNKNOWN_UNTIL_IMPORT_PREFLIGHT",
        "overlap_skip_count": "REQUIRES_REVIEW",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--batch-size", type=int, default=400)
    args = parser.parse_args()
    print(json.dumps(plan(args.seed, args.batch_size), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
