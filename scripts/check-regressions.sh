#!/bin/bash
# Run regression tests for all session bugfixes
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Backend regression tests ==="
cd "$REPO_ROOT/backend"
python -m pytest tests/test_session_regressions.py -x --tb=short -q

echo "=== Mobile analyze ==="
cd "$REPO_ROOT/mobile"
flutter analyze --no-pub lib/

echo "=== All checks passed ==="
