import json
import tempfile
import unittest
from pathlib import Path

from tool.osm_seed.build_pilot_manifest import build


class PilotManifestTest(unittest.TestCase):
    def test_locked_fixture_is_bounded_and_public_minimal(self):
        root = Path(__file__).resolve().parents[2]
        seed = root / "outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz"
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "pilot.json"
            result = build(seed, output, "osm-pilot-20260927-01",
                           "2026-09-27T00:00:00Z")
            manifest = json.loads(output.read_text(encoding="utf-8"))
            self.assertEqual((result["points"], result["aggregates"], result["total"]),
                             (346, 406, 752))
            self.assertEqual(manifest["collections"], {
                "points": "osm_vending_seed", "aggregates": "osm_vending_aggregate",
                "runs": "osm_import_runs"})
            self.assertEqual(len({row["id"] for row in manifest["points"]}), 346)
            self.assertEqual(len({row["id"] for row in manifest["aggregates"]}), 406)
            self.assertNotIn("rawTags", output.read_text(encoding="utf-8"))
            self.assertNotIn("importRunId", output.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
