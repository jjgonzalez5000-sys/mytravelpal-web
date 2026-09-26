#!/usr/bin/env bash
#
# One-time OSRM graph preparation for Western Europe (car profile):
#   ES, PT, FR, IT, DE, CH, AT, BE, NL, LU
#
# Downloads PBFs from Geofabrik, merges them and precomputes the MLD
# graph so `osrm-routed` can serve routing queries in ~10-50 ms.
#
# Idempotent — skips any step whose output already exists. Safe to
# rerun after a partial failure (curl resumes with -C -). Adding a
# country to $PBFS and re-running will pull that country and rebuild
# the merged graph from scratch (extract deletes then recreates).
#
# Disk: ~40 GB total (~16 GB PBFs + ~24 GB graph files with flatnodes).
# RAM:  peak ~15 GB during osrm-extract (thanks to --flatnodes which
#       offloads node cache to disk).
# Time: ~2-3 h on first run depending on network + CPU.
#
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$HERE/.." && pwd)"
DATA_DIR="${DATA_DIR:-$BACKEND_DIR/data/osrm}"
PROFILE="${PROFILE:-car}"
GRAPH="osrm-graph"
MIN_PBF_MB=30    # Geofabrik error pages are ~10 KB; smallest real PBF
                 # (Luxembourg) is ~40 MB. Anything below 30 MB is a
                 # download failure worth aborting on.

mkdir -p "$DATA_DIR"

echo ">>> data dir: $DATA_DIR"
echo ">>> profile:  $PROFILE"
echo ">>> target:   Western Europe (10 countries)"

# Geofabrik URLs 302-redirect to a dated snapshot; `curl -L` follows.
# Order roughly by size (small first) so early failures are cheap.
PBFS=(
  "luxembourg-latest.osm.pbf|https://download.geofabrik.de/europe/luxembourg-latest.osm.pbf"
  "portugal-latest.osm.pbf|https://download.geofabrik.de/europe/portugal-latest.osm.pbf"
  "switzerland-latest.osm.pbf|https://download.geofabrik.de/europe/switzerland-latest.osm.pbf"
  "belgium-latest.osm.pbf|https://download.geofabrik.de/europe/belgium-latest.osm.pbf"
  "austria-latest.osm.pbf|https://download.geofabrik.de/europe/austria-latest.osm.pbf"
  "netherlands-latest.osm.pbf|https://download.geofabrik.de/europe/netherlands-latest.osm.pbf"
  "spain-latest.osm.pbf|https://download.geofabrik.de/europe/spain-latest.osm.pbf"
  "italy-latest.osm.pbf|https://download.geofabrik.de/europe/italy-latest.osm.pbf"
  "germany-latest.osm.pbf|https://download.geofabrik.de/europe/germany-latest.osm.pbf"
  "france-latest.osm.pbf|https://download.geofabrik.de/europe/france-latest.osm.pbf"
)

# Parallel downloader — 4 concurrent PBFs is friendly to Geofabrik
# and near-optimal (past 4 the disk becomes the bottleneck).
CONCURRENCY="${CONCURRENCY:-4}"

download_one() {
  local name="$1"
  local url="$2"
  local target="$DATA_DIR/$name"
  local tmp="$target.tmp"
  local size_mb

  if [ -f "$target" ]; then
    size_mb=$(( $(stat -c%s "$target") / 1024 / 1024 ))
    if [ "$size_mb" -ge "$MIN_PBF_MB" ]; then
      printf "    %-32s  present (%d MB), skip\n" "$name" "$size_mb"
      return 0
    fi
    echo "!!  $name is only ${size_mb} MB, deleting and re-downloading"
    rm -f "$target"
  fi

  echo ">>> $name  starting"
  # -sSL: silent progress (avoid interleaved carriage-return spam in
  # parallel), retain error output. -C - resumes from partial .tmp.
  if ! curl -sSL --fail --retry 3 --retry-delay 5 -C - -o "$tmp" "$url"; then
    echo "!!  $name  curl failed"
    return 1
  fi

  size_mb=$(( $(stat -c%s "$tmp") / 1024 / 1024 ))
  if [ "$size_mb" -lt "$MIN_PBF_MB" ]; then
    echo "!!  $name downloaded but only ${size_mb} MB, aborting"
    return 1
  fi
  mv "$tmp" "$target"
  printf "    %-32s  saved (%d MB)\n" "$name" "$size_mb"
}

echo ">>> downloading ${#PBFS[@]} PBFs in parallel (concurrency=$CONCURRENCY)"

pids=()
for entry in "${PBFS[@]}"; do
  # Throttle: wait until fewer than CONCURRENCY children are running.
  while [ "$(jobs -pr | wc -l)" -ge "$CONCURRENCY" ]; do
    wait -n 2>/dev/null || true
  done
  name="${entry%%|*}"
  url="${entry##*|}"
  download_one "$name" "$url" &
  pids+=("$!")
done

failures=0
for pid in "${pids[@]}"; do
  wait "$pid" || failures=$((failures + 1))
done

if [ "$failures" -gt 0 ]; then
  echo "!! $failures download(s) failed. Rerun the script — completed files are cached."
  exit 1
fi

if [ ! -f "$DATA_DIR/$GRAPH.osm.pbf" ]; then
  echo ">>> merging 10 PBFs into $GRAPH.osm.pbf (~10-15 min)"
  # osmium wants all inputs on one command line
  MERGE_INPUTS=""
  for entry in "${PBFS[@]}"; do
    MERGE_INPUTS="$MERGE_INPUTS /data/${entry%%|*}"
  done
  docker run --rm \
    -v "$DATA_DIR":/data \
    stefda/osmium-tool \
    sh -c "osmium merge $MERGE_INPUTS -o /data/$GRAPH.osm.pbf"
else
  echo "    $GRAPH.osm.pbf                 present, skip merge"
fi

# Modern OSRM (v6+) uses mmap automatically — the old --flatnodes-file
# flag was retired. RAM peak on West Europe ~15-25 GB depending on
# available headroom, fits comfortably in 42 GB free.
if [ ! -f "$DATA_DIR/$GRAPH.osrm" ] || [ ! -f "$DATA_DIR/$GRAPH.osrm.names" ]; then
  echo ">>> osrm-extract ($PROFILE) — the slow one, ~60-90 min"
  docker run --rm \
    -v "$DATA_DIR":/data \
    osrm/osrm-backend \
    osrm-extract \
      -p /opt/$PROFILE.lua \
      /data/$GRAPH.osm.pbf
else
  echo "    $GRAPH.osrm.*                  present, skip extract"
fi

if [ ! -f "$DATA_DIR/$GRAPH.osrm.partition" ]; then
  echo ">>> osrm-partition (~15-30 min)"
  docker run --rm \
    -v "$DATA_DIR":/data \
    osrm/osrm-backend \
    osrm-partition /data/$GRAPH.osrm
else
  echo "    $GRAPH.osrm.partition          present, skip"
fi

if [ ! -f "$DATA_DIR/$GRAPH.osrm.cell_metrics" ]; then
  echo ">>> osrm-customize (~10-20 min)"
  docker run --rm \
    -v "$DATA_DIR":/data \
    osrm/osrm-backend \
    osrm-customize /data/$GRAPH.osrm
else
  echo "    $GRAPH.osrm.cell_metrics       present, skip"
fi

echo ""
echo ">>> OSRM graph ready (Western Europe)."
echo "    Test with:  make dev  &&  make osrm-check"
