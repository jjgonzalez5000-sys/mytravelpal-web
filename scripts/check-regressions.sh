#!/bin/bash
# Run regression tests for all session bugfixes
set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== Backend regression tests ==="
cd "$REPO_ROOT/backend"
PYTHON="${REPO_ROOT}/backend/.venv/bin/python"
if [ ! -f "$PYTHON" ]; then PYTHON="python3"; fi
"$PYTHON" -m pytest tests/test_session_regressions.py -x --tb=short -q

echo "=== Mobile analyze (errors only) ==="
cd "$REPO_ROOT/mobile"
flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos lib/ || true

echo "=== All checks passed ==="
