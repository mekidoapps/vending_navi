"""Build the locked, public-minimal 752-document OSM pilot manifest offline."""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from tool.osm_seed.benchmark_viewports import CENTERS, intersects, viewport

SEED_SHA = "0b51408d8cf648603d1db0eccd8f0ae06ce691ba42ddae2762456f66658c0e17"
SNAPSHOT = "2026-09-25T20:24:36Z"
ATTRIBUTION = "© OpenStreetMap contributors"
SOURCE_ID = re.compile(r"^osm:(node|way|relation):[1-9][0-9]*$")
CELL_ID = re.compile(r"^p([246])_([0-9bcdefghjkmnpqrstuvwxyz]+)$")
CAP = 900


def _padded(bounds: tuple[float, float, float, float]) -> tuple[float, float, float, float]:
    south, west, north, east = bounds
    return (south - (north - south) * .20, west - (east - west) * .20,
            north + (north - south) * .20, east + (east - west) * .20)


def build(seed: Path, output: Path, run_id: str, created_at: str) -> dict:
    if not re.fullmatch(r"osm-pilot-[0-9]{8}-[0-9]{2}", run_id):
        raise ValueError("invalid pilot run ID")
    if hashlib.sha256(seed.read_bytes()).hexdigest() != SEED_SHA:
        raise ValueError("canonical seed SHA mismatch")
    areas = {name: {"latitude": lat, "longitude": lon}
             for name, (lat, lon) in CENTERS.items()}
    points = []
    seen = set()
    with gzip.open(seed, "rt", encoding="utf-8") as stream:
        for line in stream:
            row = json.loads(line)
            if not any(
                (lambda box: box[0] <= row["latitude"] <= box[2] and
                 box[1] <= row["longitude"] <= box[3])(
                    _padded(viewport(lat, lon, 16)))
                for lat, lon in CENTERS.values()
            ):
                continue
            sid = row["sourceId"]
            if (not SOURCE_ID.fullmatch(sid) or sid in seen or
                row["confidence"] != "tier_A_explicit_drinks" or
                row["source"] != "OpenStreetMap" or row["license"] != "ODbL-1.0" or
                row["sourceTimestamp"] != SNAPSHOT or
                not -90 <= row["latitude"] <= 90 or
                not -180 <= row["longitude"] <= 180):
                raise ValueError(f"invalid pilot point: {sid}")
            seen.add(sid)
            data = {"sourceId": sid, "latitude": row["latitude"],
                    "longitude": row["longitude"], "geohash": row["geohash"],
                    "source": "OpenStreetMap", "sourceSnapshotId": SEED_SHA,
                    "sourceTimestamp": SNAPSHOT, "license": "ODbL-1.0",
                    "attribution": ATTRIBUTION,
                    "confidence": "tier_A_explicit_drinks", "status": "published"}
            for field in ("rawBrand", "rawOperator"):
                if row.get(field) is not None:
                    data[field] = row[field]
            points.append({"id": sid, "data": data})

    aggregates = []
    seen_cells = set()
    aggregate_summary = json.loads((seed.parent / "aggregate_summary.json")
                                   .read_text(encoding="utf-8"))
    if aggregate_summary["sourceSnapshotId"] != SEED_SHA:
        raise ValueError("aggregate summary seed mismatch")
    for precision in (2, 4, 6):
        artifact = seed.parent / f"osm_aggregate_p{precision}.ndjson.gz"
        if hashlib.sha256(artifact.read_bytes()).hexdigest() != aggregate_summary[
                "precisions"][str(precision)]["sha256"]:
            raise ValueError(f"aggregate p{precision} SHA mismatch")
        with gzip.open(artifact, "rt", encoding="utf-8") as stream:
            for line in stream:
                row = json.loads(line)
                bounds = row["bounds"]
                if precision != 2 and not any(
                    intersects((bounds["south"], bounds["west"],
                                bounds["north"], bounds["east"]),
                               _padded(viewport(lat, lon, 9 if precision == 4 else 14)))
                    for lat, lon in CENTERS.values()
                ):
                    continue
                cid = row["cellId"]
                match = CELL_ID.fullmatch(cid)
                if (not match or int(match.group(1)) != precision or
                    match.group(2) != row["geohash"] or cid in seen_cells or
                    row["count"] < 1 or row["sourceSnapshotId"] != SEED_SHA or
                    row["sourceTimestamp"] != SNAPSHOT or
                    row["source"] != "OpenStreetMap" or
                    row["license"] != "ODbL-1.0"):
                    raise ValueError(f"invalid aggregate cell: {cid}")
                seen_cells.add(cid)
                data = {key: row[key] for key in
                        ("cellId", "precision", "geohash", "count", "center",
                         "bounds", "sourceSnapshotId", "sourceTimestamp",
                         "source", "license")}
                data.update({"attribution": ATTRIBUTION, "status": "published"})
                aggregates.append({"id": cid, "data": data})

    points.sort(key=lambda item: item["id"])
    aggregates.sort(key=lambda item: item["id"])
    total = len(points) + len(aggregates)
    if (len(points), len(aggregates), total) != (346, 406, 752) or total > CAP:
        raise ValueError(f"pilot identity/count mismatch: {len(points)}/{len(aggregates)}")
    manifest = {
        "schemaVersion": 1, "mode": "pilot", "runId": run_id,
        "sourceSnapshot": SNAPSHOT, "seedSha256": SEED_SHA,
        "createdAt": created_at, "license": "ODbL-1.0",
        "attribution": ATTRIBUTION, "areas": areas,
        "collections": {"points": "osm_vending_seed",
                        "aggregates": "osm_vending_aggregate",
                        "runs": "osm_import_runs"},
        "expectedPoints": len(points), "expectedAggregates": len(aggregates),
        "expectedTotal": total, "points": points, "aggregates": aggregates,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(manifest, ensure_ascii=False, sort_keys=True,
                                 separators=(",", ":")) + "\n", encoding="utf-8")
    return {"points": len(points), "aggregates": len(aggregates),
            "total": total, "sha256": hashlib.sha256(output.read_bytes()).hexdigest()}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-id", required=True)
    parser.add_argument("--created-at", default=datetime.now(timezone.utc)
                        .isoformat(timespec="seconds").replace("+00:00", "Z"))
    args = parser.parse_args()
    print(json.dumps(build(args.seed, args.output, args.run_id,
                           args.created_at), indent=2))
