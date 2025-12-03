#!/usr/bin/env bash
# amp.dev collector — unified & extensible
# Usage:
#   ./collector.sh [-o outdir] [-C path] [-b bundles_file] [-n] [-v]
#     -o  Output directory (default: collected_ampdev)
#     -C  Chdir to path before collecting (run from repo root)
#     -b  Bundles file (default: collector.bundles)
#     -n  Dry-run (show what would be packed)
#     -v  Verbose (echo files as they’re added)
#
# Bundles file format (one line per archive):
#   <archive.tgz>|<space-separated paths...>
# Lines starting with # and blank lines are ignored.

set -Eeuo pipefail

OUTDIR="collected_ampdev"
CHDIR=""
BUNDLES_FILE="collector.bundles"
DRYRUN=0
VERBOSE=0

while getopts ":o:C:b:nv" opt; do
  case "$opt" in
    o) OUTDIR="$OPTARG" ;;
    C) CHDIR="$OPTARG" ;;
    b) BUNDLES_FILE="$OPTARG" ;;
    n) DRYRUN=1 ;;
    v) VERBOSE=1 ;;
    *) echo "Unknown option: -$OPTARG" >&2; exit 2 ;;
  esac
done

# Optional: auto-detect some common “dist” extras if present
AUTO_DIST=( "examples/static/samples/samples.json" "dist/inline-examples" "dist/examples/sources" )

log() { printf '%s\n' "$*"; }
vlog() { (( VERBOSE )) && printf '%s\n' "$*"; }

# Change to requested directory (usually repo root)
if [[ -n "$CHDIR" ]]; then
  cd "$CHDIR"
fi

# Validate bundles file
if [[ ! -f "$BUNDLES_FILE" ]]; then
  cat >&2 <<EOF
ERROR: Bundles file not found: $BUNDLES_FILE

Create it with lines like:
  ampdev_platform.tgz|platform/platform.js platform/config.js platform/serve.js platform/server.js platform/lib platform/config platform/static
  ampdev_grow.tgz|podspec.yaml content/_blueprint.yaml content/amp-dev views layouts pages/extensions
  ampdev_build.tgz|package.json gulpfile.js

(Use -b to point at a different file)
EOF
  exit 1
fi

mkdir -p "$OUTDIR"
MANIFEST="$OUTDIR/manifest.txt"
: > "$MANIFEST"

# Utility: filter to existing paths (preserves order)
existing_paths() {
  local -a kept=()
  for p in "$@"; do
    if [[ -e "$p" ]]; then
      kept+=("$p")
    fi
  done
  printf '%s\n' "${kept[@]+"${kept[@]}"}"
}

# Utility: list missing paths
missing_paths() {
  local -a missing=()
  for p in "$@"; do
    [[ -e "$p" ]] || missing+=("$p")
  done
  printf '%s\n' "${missing[@]+"${missing[@]}"}"
}

pack_bundle() {
  local archive="$1"; shift
  local -a paths=( "$@" )

  # Auto-include present “dist” extras (optional)
  for extra in "${AUTO_DIST[@]}"; do
    [[ -e "$extra" ]] && paths+=( "$extra" )
  done

  # Split to existing/missing
  mapfile -t have < <(existing_paths "${paths[@]}")
  mapfile -t miss < <(missing_paths "${paths[@]}")

  # Manifest entry
  {
    echo "=== $archive ==="
    if ((${#have[@]})); then
      printf 'INCLUDE (%d):\n' "${#have[@]}"
      printf '  - %s\n' "${have[@]}"
    else
      echo "INCLUDE (0):"
    fi
    if ((${#miss[@]})); then
      printf 'MISSING (%d):\n' "${#miss[@]}"
      printf '  - %s\n' "${miss[@]}"
    else
      echo "MISSING (0):"
    fi
    echo
  } >> "$MANIFEST"

  if (( DRYRUN )); then
    log "[dry-run] would write $OUTDIR/$archive with ${#have[@]} entries"
    return 0
  fi

  # Create the archive only from existing paths; if none, create an empty tarball
  local arcpath="$OUTDIR/$archive"
  if ((${#have[@]})); then
    vlog "tar -czf \"$arcpath\" ${have[*]}"
    tar -czf "$arcpath" "${have[@]}"
  else
    vlog "creating empty archive $arcpath (no existing paths)"
    tar -czf "$arcpath" --files-from /dev/null
  fi
  log "wrote $arcpath"
}

# Read and process bundles file
# - Strip comments and blank lines
# - Each line: "<archive>|<space-separated paths>"
while IFS= read -r raw; do
  # Trim leading/trailing whitespace
  line="${raw#"${raw%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  IFS='|' read -r arc paths <<<"$line"
  if [[ -z "$arc" || -z "$paths" ]]; then
    printf 'WARN: Skipping malformed line: %s\n' "$raw" >&2
    continue
  fi
  # shellcheck disable=SC2206
  arr=( $paths )
  pack_bundle "$arc" "${arr[@]}"
done < "$BUNDLES_FILE"

# Checksums for integrity
# Checksums for integrity
if (( ! DRYRUN )); then
  if compgen -G "$OUTDIR/*.tgz" > /dev/null; then
    ( cd "$OUTDIR" && sha256sum *.tgz > SHA256SUMS.txt )
    log "wrote $OUTDIR/SHA256SUMS.txt"
  else
    log "No archives found in $OUTDIR (skipping checksums)."
  fi
fi

log "Done. Archives + manifest in: $OUTDIR/"
