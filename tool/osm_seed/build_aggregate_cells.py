"""Build deterministic, ODbL-attributed aggregate cells from the locked seed.

Offline only. This tool has no Firebase client or Production write path.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import io
import json
import math
from collections import defaultdict
from pathlib import Path

PRECISIONS = (2, 4, 6)
BASE32 = "0123456789bcdefghjkmnpqrstuvwxyz"
ATTRIBUTION = "© OpenStreetMap contributors"
LICENSE_URL = "https://opendatacommons.org/licenses/odbl/1-0/"


def geohash_bounds(code: str) -> tuple[float, float, float, float]:
    south, north = -90.0, 90.0
    west, east = -180.0, 180.0
    longitude_bit = True
    for character in code:
        value = BASE32.index(character)
        for shift in (4, 3, 2, 1, 0):
            high = bool(value & (1 << shift))
            if longitude_bit:
                midpoint = (west + east) / 2
                west, east = (midpoint, east) if high else (west, midpoint)
            else:
                midpoint = (south + north) / 2
                south, north = (midpoint, north) if high else (south, midpoint)
            longitude_bit = not longitude_bit
    return south, west, north, east


def percentile(sorted_values: list[int], fraction: float) -> int:
    return sorted_values[max(0, math.ceil(len(sorted_values) * fraction) - 1)]


def build(seed: Path, output: Path) -> dict:
    source_sha = hashlib.sha256(seed.read_bytes()).hexdigest()
    cells: dict[int, dict[str, list[float]]] = {p: defaultdict(lambda: [0, 0.0, 0.0]) for p in PRECISIONS}
    source_timestamp = None
    records = 0
    with gzip.open(seed, "rt", encoding="utf-8") as stream:
        for line in stream:
            record = json.loads(line)
            if record.get("source") != "OpenStreetMap" or record.get("license") != "ODbL-1.0":
                raise ValueError("unexpected seed provenance")
            if source_timestamp is None:
                source_timestamp = record["sourceTimestamp"]
            elif source_timestamp != record["sourceTimestamp"]:
                raise ValueError("mixed source timestamps")
            records += 1
            for precision in PRECISIONS:
                aggregate = cells[precision][record["geohash"][:precision]]
                aggregate[0] += 1
                aggregate[1] += record["latitude"]
                aggregate[2] += record["longitude"]

    output.mkdir(parents=True, exist_ok=True)
    summary = {
        "sourceSnapshotId": source_sha,
        "sourceTimestamp": source_timestamp,
        "seedRecords": records,
        "license": "ODbL-1.0",
        "licenseUrl": LICENSE_URL,
        "attribution": ATTRIBUTION,
        "precisions": {},
    }
    for precision in PRECISIONS:
        path = output / f"osm_aggregate_p{precision}.ndjson.gz"
        with path.open("wb") as file, gzip.GzipFile(filename="", mode="wb", fileobj=file, mtime=0) as zipped, io.TextIOWrapper(zipped, encoding="utf-8", newline="\n") as text:
            for code, (count, latitude_sum, longitude_sum) in sorted(cells[precision].items()):
                south, west, north, east = geohash_bounds(code)
                document = {
                    "cellId": f"p{precision}_{code}", "precision": precision,
                    "geohash": code, "count": count,
                    "center": {"latitude": latitude_sum / count, "longitude": longitude_sum / count},
                    "bounds": {"south": south, "west": west, "north": north, "east": east},
                    "sourceSnapshotId": source_sha,
                    "sourceTimestamp": source_timestamp,
                    "source": "OpenStreetMap", "license": "ODbL-1.0",
                    "status": "candidate_not_imported",
                }
                text.write(json.dumps(document, ensure_ascii=False, separators=(",", ":")) + "\n")
        density = sorted(int(value[0]) for value in cells[precision].values())
        summary["precisions"][str(precision)] = {
            "cells": len(density), "max": density[-1],
            "median": percentile(density, 0.5),
            "p95": percentile(density, 0.95),
            "p99": percentile(density, 0.99),
            "artifact": path.name,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        }
    (output / "aggregate_summary.json").write_text(
        json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return summary


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.seed, args.output), ensure_ascii=True, indent=2))
