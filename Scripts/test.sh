#!/usr/bin/env bash
# Run unit tests for Bethal (macOS).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

SCHEME="Bethal"
PROJECT="Bethal.xcodeproj"
DESTINATION="${DESTINATION:-platform=macOS,arch=arm64}"

echo "==> Testing ${SCHEME} (${DESTINATION})"
xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -enableCodeCoverage YES \
  test \
  | xcbeautify 2>/dev/null || xcodebuild \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination "${DESTINATION}" \
  -enableCodeCoverage YES \
  test
