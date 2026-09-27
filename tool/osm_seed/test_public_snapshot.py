"""Static contract for the RC21 Hosting OSM snapshot; never connects to Firebase."""

import gzip
import hashlib
import json
import unittest
from html.parser import HTMLParser
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "hosting/data/osm-vending-seed/2026-09-26"
SEED = PUBLIC / "osm_vending_seed_jp.ndjson.gz"
SOURCE = ROOT / "outputs/osm_seed/2026-09-26/osm_vending_seed_jp.ndjson.gz"
PAGE = ROOT / "hosting/data-licenses/index.html"
EXPECTED_SHA = "0b51408d8cf648603d1db0eccd8f0ae06ce691ba42ddae2762456f66658c0e17"


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hrefs = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.hrefs.extend(value for key, value in attrs if key == "href")


class PublicSnapshotTest(unittest.TestCase):
    def test_public_artifact_is_the_locked_full_seed(self):
        self.assertEqual(SEED.read_bytes(), SOURCE.read_bytes())
        self.assertEqual(SEED.stat().st_size, 1_192_173)
        self.assertEqual(hashlib.sha256(SEED.read_bytes()).hexdigest(), EXPECTED_SHA)
        with gzip.open(SEED, "rt", encoding="utf-8") as rows:
            self.assertEqual(sum(1 for _ in rows), 40_788)

    def test_metadata_and_checksums_distinguish_pilot_from_full_seed(self):
        metadata = json.loads((PUBLIC / "source_metadata.json").read_text(encoding="utf-8"))
        pilot = json.loads(
            (ROOT / "outputs/osm_seed/2026-09-26/osm_pilot_20260927_01.manifest.json")
            .read_text(encoding="utf-8")
        )
        self.assertEqual(metadata["artifact"]["records"], 40_788)
        self.assertEqual(metadata["artifact"]["bytes"], 1_192_173)
        self.assertEqual(metadata["artifact"]["sha256"], EXPECTED_SHA)
        self.assertEqual(metadata["source"]["osmReplicationTimestamp"], "2026-09-25T20:24:36Z")
        self.assertEqual(metadata["license"]["identifier"], "ODbL-1.0")
        self.assertEqual(metadata["license"]["attribution"], "© OpenStreetMap contributors")
        self.assertEqual(metadata["productionPilotAsOf20260927"]["runId"], pilot["runId"])
        self.assertEqual(metadata["productionPilotAsOf20260927"]["pointDocuments"], 346)
        self.assertEqual(metadata["productionPilotAsOf20260927"]["aggregateDocuments"], 406)
        self.assertIs(metadata["productionPilotAsOf20260927"]["completeMapSemantics"], False)
        self.assertEqual(
            (PUBLIC / "SHA256SUMS.txt").read_text(encoding="utf-8").strip(),
            f"{EXPECTED_SHA}  {SEED.name}",
        )

    def test_license_page_links_to_each_public_file_and_official_license(self):
        page = PAGE.read_text(encoding="utf-8")
        links = Links()
        links.feed(page)
        for name in (SEED.name, "source_metadata.json", "LICENSE.txt", "SHA256SUMS.txt"):
            route = f"/data/osm-vending-seed/2026-09-26/{name}"
            self.assertIn(route, links.hrefs)
            self.assertTrue((ROOT / "hosting" / route.lstrip("/")).is_file())
        self.assertIn("https://www.openstreetmap.org/copyright", links.hrefs)
        self.assertIn("https://opendatacommons.org/licenses/odbl/1-0/", links.hrefs)
        self.assertIn("40,788件すべてが、現在アプリの地図に表示されているという意味ではありません", page)
        license_text = (PUBLIC / "LICENSE.txt").read_text(encoding="utf-8")
        self.assertIn("© OpenStreetMap contributors", license_text)
        self.assertIn("Open Database License (ODbL) 1.0", license_text)


if __name__ == "__main__":
    unittest.main()
