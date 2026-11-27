"""Run the focused VendingNavi quality gate; no application services are used."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time


FLUTTER_VERSION = "3.41.2"
DART_VERSION = "3.11.0"
FRAMEWORK_REVISION = "90673a4eef275d1a6692c26ac80d6d746d41a73a"
LOCK_SHA256 = "78c039e6df2b6a6e496aa87fcf3e74e6fbd749e14d07f15076dc0a38938f37f0"
MINIMUM_TESTS = 67

FOCUSED_TESTS = (
    "test/integration_v2/p10_search_to_detail_flow_test.dart",
    "test/integration_v2/p10_manual_product_update_flow_test.dart",
    "test/features/product_search/application/product_machine_search_controller_test.dart",
    "test/features/product_search/application/product_search_controller_test.dart",
    "test/features/home_map/application/vending_machine_map_controller_test.dart",
    "test/features/home_map/presentation/v2_home_map_product_search_test.dart",
    "test/features/home_map/presentation/v2_home_map_genre_search_test.dart",
    "test/features/home_map/presentation/v2_home_map_product_filter_status_test.dart",
    "test/features/home_map/presentation/v2_home_map_auth_gate_test.dart",
    "test/features/home_map/presentation/v2_home_map_screen_test.dart",
    "test/features/location/application/current_location_controller_test.dart",
    "test/features/location/data/mappers/geolocator_permission_mapper_test.dart",
    "test/features/auth/application/auth_required_action_runner_test.dart",
    "test/features/auth/application/email_auth_controller_test.dart",
    "test/features/auth/application/google_auth_controller_test.dart",
    "test/features/auth/data/firebase_apple_auth_client_test.dart",
    "test/features/auth/data/repositories/apple_auth_repository_impl_test.dart",
)


def run(label, argv, cwd, env):
    print(f"== {label} ==", flush=True)
    start = time.monotonic()
    result = subprocess.run(argv, cwd=cwd, env=env, check=False)
    print(f"{label}: exit={result.returncode}, seconds={time.monotonic() - start:.2f}",
          flush=True)
    return result.returncode


def summarize(report):
    events = [json.loads(line) for line in report.read_text(encoding="utf-8").splitlines()]
    done = [event for event in events if event["type"] == "done"]
    results = [event for event in events if event["type"] == "testDone"
               and not event.get("hidden", False)]
    counts = {
        "passed": sum(event["result"] == "success" and not event["skipped"]
                      for event in results),
        "failed": sum(event["result"] != "success" and not event["skipped"]
                      for event in results),
        "skipped": sum(event["skipped"] for event in results),
        "suites": sum(event["type"] == "suite" for event in events),
        "report_success": len(done) == 1 and done[0]["success"] is True,
    }
    print("TEST_RESULT " + json.dumps(counts, sort_keys=True), flush=True)
    return counts


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--flutter-sdk", required=True, type=Path)
    parser.add_argument("--offline", action="store_true",
                        help="Resolve only pre-cached packages (for a local run).")
    args = parser.parse_args()

    root = Path(__file__).resolve().parents[1]
    sdk = args.flutter_sdk.resolve()
    flutter = sdk / "bin" / ("flutter.bat" if os.name == "nt" else "flutter")
    dart = sdk / "bin" / "cache" / "dart-sdk" / "bin" / (
        "dart.exe" if os.name == "nt" else "dart"
    )
    env = os.environ.copy()
    env.update(CI="true", FLUTTER_SUPPRESS_ANALYTICS="true",
               DART_SUPPRESS_ANALYTICS="true")
    flutter_cmd = [str(flutter), "--no-version-check", "--suppress-analytics"]
    lock = root / "pubspec.lock"

    before = lock.read_bytes()
    normalized = before.replace(b"\r\n", b"\n")
    if hashlib.sha256(normalized).hexdigest() != LOCK_SHA256:
        raise ValueError("pubspec.lock does not match the vetted baseline.")

    version = subprocess.run(
        [*flutter_cmd, "--version", "--machine"], cwd=root, env=env,
        check=True, capture_output=True, encoding="utf-8",
    )
    details = json.loads(version.stdout)
    expected = {"frameworkVersion": FLUTTER_VERSION,
                "dartSdkVersion": DART_VERSION,
                "frameworkRevision": FRAMEWORK_REVISION,
                "channel": "stable"}
    if any(details.get(key) != value for key, value in expected.items()):
        raise ValueError("Flutter/Dart/framework revision does not match C2-03A.")
    print("SDK " + json.dumps(expected, sort_keys=True), flush=True)

    resolve = [*flutter_cmd, "pub", "get", "--enforce-lockfile"]
    if args.offline:
        resolve.append("--offline")
    code = run("locked dependency resolution", resolve, root, env)
    if lock.read_bytes() != before:
        raise ValueError("Dependency resolution changed pubspec.lock.")
    if code:
        return 1

    code = run(
        "static analysis (lib errors fatal; warnings and info advisory)",
        [str(dart), "analyze", "--no-fatal-warnings", "lib"],
        root,
        env,
    )
    if code:
        return 1


    code = run("static analysis (focused test files)",
               [str(dart), "analyze", "--fatal-infos", *FOCUSED_TESTS], root, env)
    if code:
        return 1

    with tempfile.TemporaryDirectory(prefix="vending-quality-") as folder:
        report = Path(folder) / "tests.jsonl"
        code = run(
            "focused Flutter regression",
            [*flutter_cmd, "test", "--no-pub", "--concurrency=2",
             "--reporter", "expanded", f"--file-reporter=json:{report}",
             *FOCUSED_TESTS],
            root, env,
        )
        if code:
            if report.is_file():
                try:
                    summarize(report)
                except (OSError, ValueError, KeyError, TypeError) as error:
                    print(f"Test report unavailable: {type(error).__name__}",
                          file=sys.stderr)
            return 1
        counts = summarize(report)
        if (counts["passed"] < MINIMUM_TESTS or counts["failed"] or counts["skipped"]
                or counts["suites"] != len(FOCUSED_TESTS)
                or not counts["report_success"]):
            raise ValueError("Incomplete or unsuccessful regression report.")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, subprocess.CalledProcessError, ValueError, KeyError,
            TypeError) as error:
        print(f"Quality gate stopped: {error}", file=sys.stderr)
        sys.exit(1)
