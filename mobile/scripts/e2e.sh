#!/bin/bash
set -e
DEVICE=${DEVICE:-} # empty = auto-detect first
FLOWS_DIR="$(dirname "$0")/../maestro/flows"
REPORTS_DIR="$(dirname "$0")/../maestro/reports"
mkdir -p "$REPORTS_DIR"

echo "=== MyTravelPal E2E smoke suite ==="
if [ -z "$DEVICE" ]; then
  DEVICE=$(adb devices | grep -v "List" | grep "device$" | head -1 | cut -f1)
fi
echo "Device: $DEVICE"

# Run all flows sequentially, collect results
PASS=0; FAIL=0
for flow in "$FLOWS_DIR"/*.yaml; do
  name=$(basename "$flow" .yaml)
  echo -n "  $name ... "
  if maestro --device "$DEVICE" test "$flow" --format junit --output "$REPORTS_DIR/${name}.xml" >"$REPORTS_DIR/${name}.log" 2>&1; then
    echo "PASS"; PASS=$((PASS+1))
  else
    echo "FAIL"; tail -n 25 "$REPORTS_DIR/${name}.log"; FAIL=$((FAIL+1))
  fi
done

echo "=== Results: $PASS passed, $FAIL failed ==="
[ $FAIL -eq 0 ] || exit 1
