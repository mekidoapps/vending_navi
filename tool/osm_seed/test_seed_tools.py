import gzip
import json
import tempfile
import unittest
from pathlib import Path

from analyze_overlap import bucket, distance_m
from extract_japan_pbf import geohash, normalize_brand, tier, varint, zigzag
from plan_import import plan


class SeedToolsTest(unittest.TestCase):
    def test_conservative_tiers(self):
        self.assertEqual(tier({"amenity": "vending_machine", "vending": "drinks"}), "A")
        self.assertEqual(tier({"vending": "food"}), "excluded_non_drink")
        self.assertEqual(tier({"operator": "Suntory"}), "B")
        self.assertEqual(tier({"manufacturer": "Suntory"}), "unknown")
        self.assertEqual(normalize_brand({"operator": "Suntory"}), "Suntory")

    def test_geohash_and_pbf_primitives(self):
        self.assertEqual(geohash(35.681236, 139.767125, 6), "xn76ur")
        self.assertEqual(varint(bytes([0xAC, 0x02]), 0), (300, 2))
        self.assertEqual(zigzag(3), -2)

    def test_overlap_buckets(self):
        self.assertEqual(bucket(distance_m((35.0, 139.0), (35.0, 139.0))), "very_close_10m")
        self.assertEqual(bucket(distance_m((35.0, 139.0), (35.001, 139.0))), "unique_over_50m")

    def test_import_dry_run_is_idempotent_and_rejects_products(self):
        with tempfile.TemporaryDirectory() as directory:
            seed = Path(directory) / "seed.ndjson.gz"
            row = {
                "sourceId": "osm:node:123", "source": "OpenStreetMap",
                "license": "ODbL-1.0", "confidence": "tier_A_explicit_drinks",
                "latitude": 35.0, "longitude": 139.0,
            }
            with gzip.open(seed, "wt", encoding="utf-8") as output:
                output.write(json.dumps(row) + "\n")
            self.assertEqual(plan(seed)["production_writes"], 0)
            with gzip.open(seed, "wt", encoding="utf-8") as output:
                output.write(json.dumps(row) + "\n" + json.dumps(row) + "\n")
            with self.assertRaisesRegex(ValueError, "duplicate source ID"):
                plan(seed)
            row["products"] = ["inferred"]
            with gzip.open(seed, "wt", encoding="utf-8") as output:
                output.write(json.dumps(row) + "\n")
            with self.assertRaisesRegex(ValueError, "inferred product/user field"):
                plan(seed)


if __name__ == "__main__":
    unittest.main()
