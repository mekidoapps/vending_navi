"""Extract a reviewable Japan drink-vending seed from a Geofabrik OSM PBF.

Uses only the Python standard library. This is an offline preparation tool: it
does not connect to Firebase, import records, or modify production data.
"""

from __future__ import annotations

import argparse
import csv
import gzip
import hashlib
import io
import json
import math
import struct
import time
import zlib
from collections import Counter
from pathlib import Path

COPYRIGHT = "© OpenStreetMap contributors"
COPYRIGHT_URL = "https://www.openstreetmap.org/copyright"
ODBL_URL = "https://opendatacommons.org/licenses/odbl/1-0/"
FILTER_VERSION = "drink-v1"
GEOHASH_ALPHABET = "0123456789bcdefghjkmnpqrstuvwxyz"

# Conservative candidate mapping; raw values are always retained separately.
BRANDS = {
    "coca-cola": "Coca-Cola",
    "coca cola": "Coca-Cola",
    "コカ・コーラ": "Coca-Cola",
    "suntory": "Suntory",
    "サントリー": "Suntory",
    "asahi": "Asahi",
    "アサヒ": "Asahi",
    "dydo": "DyDo",
    "ダイドー": "DyDo",
    "kirin": "Kirin",
    "キリン": "Kirin",
    "ito en": "Ito En",
    "伊藤園": "Ito En",
    "pokka sapporo": "Pokka Sapporo",
    "ポッカサッポロ": "Pokka Sapporo",
    "cheerio": "Cheerio",
    "チェリオ": "Cheerio",
    "yakult": "Yakult",
    "ヤクルト": "Yakult",
}
NON_DRINK_VENDING = {
    "cigarettes", "tickets", "parking_tickets", "food", "condoms",
    "newspapers", "stamps", "toys", "ice_cream", "snacks", "bicycle_tube",
}


def varint(data: bytes | memoryview, pos: int) -> tuple[int, int]:
    value = 0
    shift = 0
    while True:
        byte = data[pos]
        pos += 1
        value |= (byte & 0x7F) << shift
        if byte < 0x80:
            return value, pos
        shift += 7
        if shift > 70:
            raise ValueError("invalid PBF varint")


def zigzag(value: int) -> int:
    return (value >> 1) ^ -(value & 1)


def signed_int64(value: int) -> int:
    return value - (1 << 64) if value >= (1 << 63) else value


def fields(data: bytes | memoryview):
    pos = 0
    while pos < len(data):
        key, pos = varint(data, pos)
        number, wire = key >> 3, key & 7
        if wire == 0:
            value, pos = varint(data, pos)
        elif wire == 2:
            size, pos = varint(data, pos)
            value = data[pos:pos + size]
            pos += size
        elif wire == 1:
            value = data[pos:pos + 8]
            pos += 8
        elif wire == 5:
            value = data[pos:pos + 4]
            pos += 4
        else:
            raise ValueError(f"unsupported PBF wire type: {wire}")
        yield number, wire, value


def packed(data: bytes | memoryview, signed: bool = False):
    pos = 0
    while pos < len(data):
        value, pos = varint(data, pos)
        yield zigzag(value) if signed else value


def blocks(path: Path):
    with path.open("rb") as stream:
        while length_bytes := stream.read(4):
            if len(length_bytes) != 4:
                raise ValueError("truncated PBF block header")
            header_size = struct.unpack(">I", length_bytes)[0]
            header = stream.read(header_size)
            kind = ""
            data_size = None
            for number, _, value in fields(header):
                if number == 1:
                    kind = bytes(value).decode("ascii")
                elif number == 3:
                    data_size = value
            if data_size is None:
                raise ValueError("PBF blob size missing")
            blob = stream.read(data_size)
            if len(blob) != data_size:
                raise ValueError("truncated PBF blob")
            raw = None
            compressed = None
            for number, _, value in fields(blob):
                if number == 1:
                    raw = bytes(value)
                elif number == 3:
                    compressed = bytes(value)
            if raw is None:
                if compressed is None:
                    raise ValueError("unsupported PBF compression")
                raw = zlib.decompress(compressed)
            yield kind, raw


def pbf_replication_timestamp(path: Path) -> str:
    kind, header = next(blocks(path))
    if kind != "OSMHeader":
        raise ValueError("OSM PBF header missing")
    for number, _, value in fields(header):
        if number == 32:
            return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(value))
    raise ValueError("OSM replication timestamp missing")


def file_hashes(path: Path) -> dict[str, str]:
    sha256 = hashlib.sha256()
    md5 = hashlib.md5()
    with path.open("rb") as source:
        while chunk := source.read(1024 * 1024):
            sha256.update(chunk)
            md5.update(chunk)
    return {"sha256": sha256.hexdigest(), "md5": md5.hexdigest()}


def tag_map(keys: list[int], values: list[int], strings: list[bytes]) -> dict[str, str]:
    return {
        strings[key].decode("utf-8", "replace"): strings[value].decode("utf-8", "replace")
        for key, value in zip(keys, values)
    }


def is_vending_machine(keys: list[int], values: list[int], strings: list[bytes]) -> bool:
    return any(
        strings[key] == b"amenity" and strings[value] == b"vending_machine"
        for key, value in zip(keys, values)
    )


def selected_tags(tags: dict[str, str]) -> dict[str, str]:
    return {key: tags[key] for key in ("amenity", "vending", "brand", "operator", "manufacturer") if key in tags}


def normalize_brand(tags: dict[str, str]) -> str | None:
    for field in ("brand", "operator"):
        value = tags.get(field, "").strip().casefold()
        if value in BRANDS:
            return BRANDS[value]
    return None


def tier(tags: dict[str, str]) -> str:
    vending = {part.strip().casefold() for part in tags.get("vending", "").split(";") if part.strip()}
    if "drinks" in vending:
        return "A"
    if vending & NON_DRINK_VENDING:
        return "excluded_non_drink"
    if (not vending or vending <= {"yes", "unknown", "other"}) and normalize_brand(tags):
        return "B"
    return "unknown"


def geohash(latitude: float, longitude: float, precision: int = 9) -> str:
    lat_range = [-90.0, 90.0]
    lon_range = [-180.0, 180.0]
    bits = []
    for index in range(precision * 5):
        bounds = lon_range if index % 2 == 0 else lat_range
        coordinate = longitude if index % 2 == 0 else latitude
        midpoint = (bounds[0] + bounds[1]) / 2
        bit = int(coordinate >= midpoint)
        bounds[bit ^ 1] = midpoint
        bits.append(bit)
    return "".join(
        GEOHASH_ALPHABET[sum(bits[index + offset] << (4 - offset) for offset in range(5))]
        for index in range(0, len(bits), 5)
    )


def point_in_ring(lon: float, lat: float, ring: list) -> bool:
    inside = False
    prev_x, prev_y = ring[-1]
    for x, y in ring:
        if (y > lat) != (prev_y > lat):
            crossed_x = (prev_x - x) * (lat - y) / (prev_y - y) + x
            if lon < crossed_x:
                inside = not inside
        prev_x, prev_y = x, y
    return inside


def prefecture_for(lon: float, lat: float, polygons: list) -> str | None:
    for name, min_x, min_y, max_x, max_y, parts in polygons:
        if not (min_x <= lon <= max_x and min_y <= lat <= max_y):
            continue
        for part_min_x, part_min_y, part_max_x, part_max_y, rings in parts:
            if not (part_min_x <= lon <= part_max_x and part_min_y <= lat <= part_max_y):
                continue
            if point_in_ring(lon, lat, rings[0]) and not any(
                point_in_ring(lon, lat, hole) for hole in rings[1:]
            ):
                return name
    return None


def load_prefectures(path: Path) -> list:
    features = json.loads(path.read_text(encoding="utf-8"))["features"]
    result = []
    for feature in features:
        geometry = feature["geometry"]
        parts = geometry["coordinates"] if geometry["type"] == "MultiPolygon" else [geometry["coordinates"]]
        indexed_parts = []
        for rings in parts:
            outer = rings[0]
            xs, ys = zip(*((point[0], point[1]) for point in outer))
            indexed_parts.append((min(xs), min(ys), max(xs), max(ys), rings))
        name = feature["properties"].get("shapeName", "UNKNOWN")
        result.append((name,
                       min(part[0] for part in indexed_parts),
                       min(part[1] for part in indexed_parts),
                       max(part[2] for part in indexed_parts),
                       max(part[3] for part in indexed_parts),
                       indexed_parts))
    return result


def elements(path: Path, wanted_node_refs: set[int] | None = None):
    """Yield tagged candidates, or targeted node coordinates in pass two."""
    for kind, raw in blocks(path):
        if kind != "OSMData":
            continue
        strings = []
        groups = []
        granularity = 100
        lat_offset = lon_offset = 0
        for number, _, value in fields(raw):
            if number == 1:
                strings = [bytes(item) for field, _, item in fields(value) if field == 1]
            elif number == 2:
                groups.append(value)
            elif number == 17:
                granularity = value
            elif number == 19:
                lat_offset = signed_int64(value)
            elif number == 20:
                lon_offset = signed_int64(value)
        for group in groups:
            for number, _, value in fields(group):
                if number == 2:  # DenseNodes
                    node_ids = node_lats = node_lons = key_values = None
                    for field, _, item in fields(value):
                        if field == 1:
                            node_ids = packed(item, signed=True)
                        elif field == 8:
                            node_lats = packed(item, signed=True)
                        elif field == 9:
                            node_lons = packed(item, signed=True)
                        elif field == 10 and wanted_node_refs is None:
                            key_values = packed(item)
                    if node_ids is None or node_lats is None or node_lons is None:
                        continue
                    ids_sum = lat_sum = lon_sum = 0
                    for id_delta, lat_delta, lon_delta in zip(node_ids, node_lats, node_lons):
                        ids_sum += id_delta
                        lat_sum += lat_delta
                        lon_sum += lon_delta
                        if wanted_node_refs is not None:
                            if ids_sum in wanted_node_refs:
                                yield "coordinate", ids_sum, None, (lat_offset + granularity * lat_sum) / 1e9, (lon_offset + granularity * lon_sum) / 1e9
                            continue
                        keys = []
                        values = []
                        if key_values is not None:
                            while (key := next(key_values)) != 0:
                                keys.append(key)
                                values.append(next(key_values))
                        if keys and is_vending_machine(keys, values, strings):
                            tags = tag_map(keys, values, strings)
                            yield "node", ids_sum, tags, (lat_offset + granularity * lat_sum) / 1e9, (lon_offset + granularity * lon_sum) / 1e9
                elif number == 1:  # Non-dense Node
                    item = {field: part for field, _, part in fields(value)}
                    node_id = zigzag(item[1])
                    if wanted_node_refs is not None:
                        if node_id in wanted_node_refs:
                            yield "coordinate", node_id, None, (lat_offset + granularity * zigzag(item[8])) / 1e9, (lon_offset + granularity * zigzag(item[9])) / 1e9
                        continue
                    keys = list(packed(item[2])) if 2 in item else []
                    values = list(packed(item[3])) if 3 in item else []
                    if is_vending_machine(keys, values, strings):
                        tags = tag_map(keys, values, strings)
                        yield "node", node_id, tags, (lat_offset + granularity * zigzag(item[8])) / 1e9, (lon_offset + granularity * zigzag(item[9])) / 1e9
                elif number in (3, 4) and wanted_node_refs is None:
                    item = {field: part for field, _, part in fields(value)}
                    keys = list(packed(item[2])) if 2 in item else []
                    values = list(packed(item[3])) if 3 in item else []
                    if not is_vending_machine(keys, values, strings):
                        continue
                    tags = tag_map(keys, values, strings)
                    refs = []
                    if number == 3 and 8 in item:
                        ref_sum = 0
                        for delta in packed(item[8], signed=True):
                            ref_sum += delta
                            refs.append(ref_sum)
                    yield ("way" if number == 3 else "relation"), item[1], tags, refs, None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pbf", type=Path, required=True)
    parser.add_argument("--prefectures", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-modified-utc", help="HTTP Last-Modified evidence")
    parser.add_argument("--published-md5", help="Geofabrik-published MD5 checksum")
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    snapshot_timestamp = pbf_replication_timestamp(args.pbf)
    polygons = load_prefectures(args.prefectures)
    counts = Counter()
    coverage = Counter()
    prefectures = Counter()
    unresolved_ways = []
    refs_needed = set()
    records = []
    seen_ids = set()
    for element in elements(args.pbf):
        kind, element_id, tags, latitude, longitude = element
        counts["all_vending_machines"] += 1
        source_id = f"osm:{kind}:{element_id}"
        if source_id in seen_ids:
            counts["duplicate_source_ids"] += 1
            continue
        seen_ids.add(source_id)
        category = tier(tags)
        counts[f"tier_{category}"] += 1
        if kind == "node" and not (
            math.isfinite(latitude) and math.isfinite(longitude)
            and -90 <= latitude <= 90 and -180 <= longitude <= 180
        ):
            counts["invalid_coordinate"] += 1
            continue
        if category != "A":
            continue
        for key in ("brand", "operator", "manufacturer"):
            if tags.get(key, "").strip():
                coverage[key] += 1
        if normalize_brand(tags):
            coverage["normalized_beverage_brand"] += 1
        if kind == "relation":
            counts["unresolved_relations"] += 1
            continue
        if kind == "way":
            unresolved_ways.append((kind, element_id, tags, latitude))
            refs_needed.update(latitude)
            continue
        records.append((kind, element_id, tags, latitude, longitude))
    if refs_needed:
        coordinates = {}
        for _, node_id, _, lat, lon in elements(args.pbf, refs_needed):
            coordinates[node_id] = (lat, lon)
        for kind, element_id, tags, refs in unresolved_ways:
            points = [coordinates[ref] for ref in refs if ref in coordinates]
            if not points:
                counts["unresolved_ways"] += 1
                continue
            # Approximate point for mapped area; review before production import.
            records.append((kind, element_id, tags, sum(p[0] for p in points) / len(points), sum(p[1] for p in points) / len(points)))
    output_path = args.output / "osm_vending_seed_jp.ndjson.gz"
    with output_path.open("wb") as binary_output, gzip.GzipFile(
        filename="", mode="wb", fileobj=binary_output, mtime=0
    ) as compressed_output, io.TextIOWrapper(
        compressed_output, encoding="utf-8", newline="\n"
    ) as output:
        for kind, element_id, tags, latitude, longitude in sorted(records, key=lambda r: (r[0], r[1])):
            if not (math.isfinite(latitude) and math.isfinite(longitude) and -90 <= latitude <= 90 and -180 <= longitude <= 180):
                if kind != "node":
                    counts["invalid_coordinate"] += 1
                continue
            prefecture = prefecture_for(longitude, latitude, polygons)
            prefectures[prefecture or "UNASSIGNED"] += 1
            payload = {
                "sourceId": f"osm:{kind}:{element_id}",
                "source": "OpenStreetMap",
                "osmElementType": kind,
                "osmElementId": element_id,
                "latitude": latitude,
                "longitude": longitude,
                "geohash": geohash(latitude, longitude),
                "rawTags": selected_tags(tags),
                "rawBrand": tags.get("brand"),
                "rawOperator": tags.get("operator"),
                "rawManufacturer": tags.get("manufacturer"),
                "normalizedBrand": normalize_brand(tags),
                "vending": tags.get("vending"),
                "prefecture": prefecture,
                "sourceTimestamp": snapshot_timestamp,
                "license": "ODbL-1.0",
                "confidence": "tier_A_explicit_drinks",
                "status": "candidate_not_imported",
            }
            output.write(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n")
            counts["seed_records"] += 1
    digest = file_hashes(output_path)["sha256"]
    source_hashes = file_hashes(args.pbf)
    if args.published_md5 and source_hashes["md5"].lower() != args.published_md5.lower():
        raise ValueError("Geofabrik PBF MD5 mismatch")
    summary = {
        "counts": dict(counts),
        "coverage": dict(coverage),
        "prefectures": dict(prefectures),
        "seed_sha256": digest,
        "seed_bytes": output_path.stat().st_size,
        "source_file": args.pbf.name,
        "source_sha256": source_hashes["sha256"],
        "source_md5": source_hashes["md5"],
        "published_md5_verified": bool(args.published_md5),
        "source_modified_utc": args.source_modified_utc,
        "osm_replication_timestamp": snapshot_timestamp,
        "extracted_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "filter_version": FILTER_VERSION,
        "boundary_source": "geoBoundaries gbOpen JPN ADM1, source OpenStreetMap/Wambacher, ODbL 1.0",
    }
    (args.output / "summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    source_metadata = {
        "source_url": "https://download.geofabrik.de/asia/japan-latest.osm.pbf",
        "source_file_modified_utc": args.source_modified_utc,
        "source_sha256": summary["source_sha256"],
        "source_md5": summary["source_md5"],
        "published_md5_verified": summary["published_md5_verified"],
        "osm_replication_timestamp": snapshot_timestamp,
        "extracted_utc": summary["extracted_utc"],
        "filter_version": FILTER_VERSION,
        "attribution": COPYRIGHT,
        "copyright_url": COPYRIGHT_URL,
        "license": "ODbL-1.0",
        "license_url": ODBL_URL,
        "prefecture_boundary": "geoBoundaries gbOpen JPN ADM1 (OpenStreetMap/Wambacher, ODbL-1.0)",
    }
    (args.output / "source_metadata.json").write_text(json.dumps(source_metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.output / "license.txt").write_text(f"{COPYRIGHT}\n{COPYRIGHT_URL}\nOpen Database License (ODbL) 1.0: {ODBL_URL}\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
