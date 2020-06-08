#!/usr/bin/env bash

# XXX Maybe this should have been a Python script inside the pipeline proper?

DEFAULT_URL=https://download.ebird.org/ebd/prepackaged/ebd_relApr-2020.tar
DEFAULT_OUTPUT_FILE=sources/ebird/ebd_relApr-2020.tar

if [[ $# < 1 ]]; then
  echo "Helper script to download the 95 GB eBird Basic Dataset in parallel."
  echo "Needed because their server only gives 600 kB/s or so on average,"
  echo "which means a download would take over 2 days."
  echo ""
  echo "Usage:  $0 COOKIE [URL [OUTPUT_FILE]]"
  echo "where"
  echo "    COOKIE       is the cookie header of the form 'Cookie: ...' and can be copied from a browser"
  echo "    URL          is the absolute URL to download (defaults to $DEFAULT_URL)"
  echo "    OUTPUT_FILE  is the path to the output file (defaults to $DEFAULT_OUTPUT_FILE)"
  exit 1
fi

set -e # Exit on error.
set -u # Reject undefined variables.
set -o pipefail # Fail pipelines if any part failed.

COOKIE="$1"
URL="${2:-$DEFAULT_URL}"
OUTPUT_FILE="${3:-$DEFAULT_OUTPUT_FILE}"

TOTAL_SIZE=$(curl -s --head "$URL" --header "$COOKIE" | tr -d '\r' | grep -i 'content-length' | cut -d' ' -f2)
>&2 echo "Total size: $TOTAL_SIZE"
CHUNK_SIZE=$((100 * 1000 * 1000)) # 100 MB
>&2 echo "Chunk size: $CHUNK_SIZE"
NUM_CHUNKS=$((($TOTAL_SIZE + $CHUNK_SIZE - 1) / $CHUNK_SIZE))
>&2 echo "Number of chunks: $NUM_CHUNKS"
for ((i = 0; $i < $NUM_CHUNKS; i++)); do
  CHUNK_START=$(($i * $CHUNK_SIZE))
  CHUNK_END=$(($CHUNK_START + $CHUNK_SIZE - 1))
  CHUNK_FILE="$OUTPUT_FILE.part$(printf '%04d' $i)"
  # curl's --continue-at option doesn't seem to play nice with --range: it just
  # continues from the end of the range onwards. So we just check the size of
  # the output file and re-download it from scratch if needed.
  FILE_SIZE=$(stat --format=%s "$CHUNK_FILE" 2>/dev/null || true)
  if [[ $FILE_SIZE == $CHUNK_SIZE ]]; then
    >&2 echo "Output file $CHUNK_FILE is already $CHUNK_SIZE bytes, assuming complete"
    continue
  elif [[ -f $CHUNK_FILE ]]; then
    >&2 echo "Output file $CHUNK_FILE exists but is $FILE_SIZE != $CHUNK_SIZE bytes, re-downloading"
  fi
  echo "curl '$URL' --header '$COOKIE' --no-progress-meter --range $CHUNK_START-$CHUNK_END --output '$CHUNK_FILE'"
done | parallel --dry-run --jobs 8 --ungroup --progress --bar --eta '{}'
