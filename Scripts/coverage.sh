#!/usr/bin/env bash
# Run tests with code coverage and print a summary for Domain sources.
# Target: 100% line coverage on Domain/* (testable pure logic).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="Bethal"
PROJECT="Bethal.xcodeproj"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"
RESULT_BUNDLE="${ROOT}/.build/TestResults.xcresult"

rm -rf "${RESULT_BUNDLE}"
mkdir -p "${ROOT}/.build"

echo "==> Running tests with coverage → ${RESULT_BUNDLE}"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -enableCodeCoverage YES \
  -resultBundlePath "${RESULT_BUNDLE}" \
  test

echo ""
echo "==> Coverage report (xccov)"
xcrun xccov view --report --only-targets "${RESULT_BUNDLE}" || true

echo ""
echo "==> Domain file coverage"
# List files and fail if any Domain source is under 100% line coverage.
REPORT_JSON="$(mktemp)"
xcrun xccov view --report --json "${RESULT_BUNDLE}" > "${REPORT_JSON}"

python3 - "${REPORT_JSON}" <<'PY'
import json, sys

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

DOMAIN_BASENAMES = {"AppIdentity.swift", "ProjectLayout.swift"}
failures = []
domain_files = []

for target in data.get("targets", []):
    name = target.get("name", "")
    if "Tests" in name:
        continue
    if "Bethal" not in name:
        continue
    for f in target.get("files", []):
        file_path = f.get("path") or f.get("name") or ""
        base = file_path.split("/")[-1]
        is_domain = ("/Domain/" in file_path) or file_path.startswith("Domain/") or (base in DOMAIN_BASENAMES)
        if not is_domain:
            continue
        lines = f.get("coveredLines", 0)
        total = f.get("executableLines", 0)
        pct = f.get("lineCoverage", 0.0) * 100.0
        domain_files.append((file_path, lines, total, pct))
        if total > 0 and pct < 99.999:
            failures.append(f"{file_path}: {pct:.1f}% ({lines}/{total})")

if not domain_files:
    print("No Domain files found in coverage report; listing app target files:")
    for target in data.get("targets", []):
        print("target:", target.get("name"))
        for f in target.get("files", []):
            print(" ", f.get("path") or f.get("name"), "coverage=", f.get("lineCoverage"))
    sys.exit(1)

for file_path, lines, total, pct in sorted(domain_files):
    print(f"  {file_path}: {pct:.1f}% ({lines}/{total} lines)")

if failures:
    print("\nFAIL: Domain coverage below 100%:")
    for msg in failures:
        print(" ", msg)
    sys.exit(1)

print("\nOK: Domain sources at 100% line coverage.")
PY

rm -f "${REPORT_JSON}"
