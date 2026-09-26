"""Offline seed-density benchmark for representative 400x800 logical-pixel viewports."""

from __future__ import annotations

import argparse
import gzip
import json
import math
from collections import Counter
from pathlib import Path

from tool.osm_seed.build_aggregate_cells import geohash_bounds

CENTERS = {
    "Tokyo dense": (35.6812, 139.7671),
    "Osaka dense": (34.7025, 135.4959),
    "normal urban": (35.1709, 136.8815),
    "suburban": (36.0835, 140.0764),
}
ZOOMS = (5, 8, 9, 10, 12, 14, 15, 16, 17)


def viewport(latitude: float, longitude: float, zoom: int) -> tuple[float, float, float, float]:
    width = 400 / (256 * 2**zoom) * 360
    height = 800 / (256 * 2**zoom) * 360 * math.cos(math.radians(latitude))
    return latitude - height / 2, longitude - width / 2, latitude + height / 2, longitude + width / 2


def intersects(a: tuple[float, float, float, float], b: tuple[float, float, float, float]) -> bool:
    return a[0] <= b[2] and a[2] >= b[0] and a[1] <= b[3] and a[3] >= b[1]


def benchmark(seed: Path) -> list[dict]:
    records = [json.loads(line) for line in gzip.open(seed, "rt", encoding="utf-8")]
    cells = {p: Counter(record["geohash"][:p] for record in records) for p in (2, 4, 6)}
    results = []
    for name, (latitude, longitude) in CENTERS.items():
        for zoom in ZOOMS:
            bounds = viewport(latitude, longitude, zoom)
            visible = [r for r in records if bounds[0] <= r["latitude"] <= bounds[2] and bounds[1] <= r["longitude"] <= bounds[3]]
            results.append({
                "case": name, "zoom": zoom, "pointDocsIfUnbounded": len(visible),
                "aggregateCells": {
                    str(p): sum(intersects(geohash_bounds(code), bounds) for code in cells[p])
                    for p in cells
                },
            })
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = benchmark(args.seed)
    if args.output:
        args.output.write_text(json.dumps(result, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=True, indent=2))
