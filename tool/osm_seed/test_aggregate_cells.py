import gzip
import json
import tempfile
import unittest
from pathlib import Path

from tool.osm_seed.build_aggregate_cells import build, geohash_bounds
from tool.osm_seed.benchmark_viewports import benchmark


class AggregateCellsTest(unittest.TestCase):
    def test_locked_seed_viewport_budgets(self):
        root = Path(__file__).resolve().parents[2]
        seed = root / "outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz"
        cases = {(row["case"], row["zoom"]): row for row in benchmark(seed)}
        self.assertGreater(cases[("Tokyo dense", 8)]["aggregateCells"]["4"], 80)
        for city in ("Tokyo dense", "Osaka dense", "normal urban", "suburban"):
            self.assertLessEqual(cases[(city, 9)]["aggregateCells"]["4"], 80)
            self.assertLessEqual(cases[(city, 16)]["pointDocsIfUnbounded"], 120)

    def test_bounds_and_deterministic_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            seed = root / "seed.ndjson.gz"
            rows = [
                {"source": "OpenStreetMap", "license": "ODbL-1.0", "sourceTimestamp": "2026-09-25T20:24:36Z", "geohash": "xn76ur", "latitude": 35.68, "longitude": 139.76},
                {"source": "OpenStreetMap", "license": "ODbL-1.0", "sourceTimestamp": "2026-09-25T20:24:36Z", "geohash": "xn76ur", "latitude": 35.69, "longitude": 139.77},
            ]
            with seed.open("wb") as file:
                with gzip.GzipFile(filename="", mode="wb", fileobj=file, mtime=0) as zipped:
                    zipped.write("".join(json.dumps(row) + "\n" for row in rows).encode())
            summary = build(seed, root / "output")
            self.assertEqual(summary["seedRecords"], 2)
            self.assertEqual(summary["precisions"]["6"]["cells"], 1)
            self.assertEqual(summary["precisions"]["6"]["max"], 2)
            with gzip.open(root / "output" / "osm_aggregate_p6.ndjson.gz", "rt", encoding="utf-8") as stream:
                cell = json.loads(stream.readline())
            self.assertEqual(cell["cellId"], "p6_xn76ur")
            self.assertEqual(cell["count"], 2)
            self.assertEqual(cell["status"], "candidate_not_imported")
            self.assertEqual(cell["license"], "ODbL-1.0")
            self.assertEqual(geohash_bounds("xn76ur"), tuple(cell["bounds"][name] for name in ("south", "west", "north", "east")))
            original_hash = summary["precisions"]["6"]["sha256"]
            self.assertEqual(build(seed, root / "output")["precisions"]["6"]["sha256"], original_hash)


if __name__ == "__main__":
    unittest.main()
