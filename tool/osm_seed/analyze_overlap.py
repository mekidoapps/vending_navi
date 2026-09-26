"""Read-only proximity review for an extracted OSM seed and native machines.

Distances are review buckets, never automatic merge decisions. The 10 m bucket
reflects approximate map-pin uncertainty; 50 m is a broader manual-review
radius for adjacent machines at the same site.
"""

from __future__ import annotations

import argparse
import gzip
import json
import math
from collections import Counter, defaultdict
from pathlib import Path


def distance_m(a: tuple[float, float], b: tuple[float, float]) -> float:
    lat1, lon1 = map(math.radians, a)
    lat2, lon2 = map(math.radians, b)
    delta_lat = lat2 - lat1
    delta_lon = lon2 - lon1
    haversine = math.sin(delta_lat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(delta_lon / 2) ** 2
    return 12742000 * math.asin(min(1.0, math.sqrt(haversine)))


def bucket(distance: float) -> str:
    if distance <= 10:
        return "very_close_10m"
    if distance <= 50:
        return "near_50m"
    return "unique_over_50m"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--native", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    native = json.loads(args.native.read_text(encoding="utf-8-sig"))
    native_points = [(item["latitude"], item["longitude"]) for item in native]
    native_counts = Counter()
    internal_counts = Counter()
    unique_after_proximity = 0
    exact_coordinate_duplicates = 0
    seen_coordinates = set()
    grid = defaultdict(list)
    with gzip.open(args.seed, "rt", encoding="utf-8") as source:
        for line in source:
            record = json.loads(line)
            point = (record["latitude"], record["longitude"])
            if point in seen_coordinates:
                exact_coordinate_duplicates += 1
            seen_coordinates.add(point)
            closest_native = min((distance_m(point, other) for other in native_points), default=math.inf)
            native_counts[bucket(closest_native)] += 1
            # 0.001 degrees is ~110 m latitude. Search adjacent cells as well.
            cell = (math.floor(point[0] * 1000), math.floor(point[1] * 1000))
            closest_osm = math.inf
            for delta_lat in (-1, 0, 1):
                for delta_lon in (-1, 0, 1):
                    for other in grid[(cell[0] + delta_lat, cell[1] + delta_lon)]:
                        closest_osm = min(closest_osm, distance_m(point, other))
            internal_counts[bucket(closest_osm)] += 1
            if closest_native > 50 and closest_osm > 10:
                unique_after_proximity += 1
            grid[cell].append(point)
    result = {
        "native_with_coordinates": len(native_points),
        "native_overlap": {name: native_counts[name] for name in ("very_close_10m", "near_50m", "unique_over_50m")},
        "osm_internal_proximity": {name: internal_counts[name] for name in ("very_close_10m", "near_50m", "unique_over_50m")},
        "exact_coordinate_duplicates": exact_coordinate_duplicates,
        "unique_after_proximity_review": unique_after_proximity,
        "automatic_merge": False,
        "thresholds_m": {"very_close": 10, "near": 50},
    }
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
