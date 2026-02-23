#!/usr/bin/env bash
set -euo pipefail

# bugboard-id.sh — Returns the next BUG-XXXX ID based on .bugboard/board.md.
#
# Usage: bash scripts/bugboard-id.sh [project-dir]
#   project-dir defaults to current working directory
#
# Exit 0 with ID on stdout, exit 1 if .bugboard/ doesn't exist.

PROJECT_DIR="${1:-.}"
BUGBOARD_DIR="${PROJECT_DIR}/.bugboard"
BOARD_FILE="${BUGBOARD_DIR}/board.md"

if [ ! -d "$BUGBOARD_DIR" ]; then
  echo "Error: .bugboard/ not found in ${PROJECT_DIR}. Run bugboard-init.sh first." >&2
  exit 1
fi

if [ ! -f "$BOARD_FILE" ]; then
  echo "Error: board.md not found in ${BUGBOARD_DIR}." >&2
  exit 1
fi

# Read config for prefix and digits (defaults: BUG, 4)
CONFIG_FILE="${BUGBOARD_DIR}/config.json"
if [ -f "$CONFIG_FILE" ] && command -v python3 &>/dev/null; then
  PREFIX=$(python3 -c "import json; print(json.load(open('${CONFIG_FILE}')).get('id_prefix', 'BUG'))" 2>/dev/null || echo "BUG")
  DIGITS=$(python3 -c "import json; print(json.load(open('${CONFIG_FILE}')).get('id_digits', 4))" 2>/dev/null || echo "4")
else
  PREFIX="BUG"
  DIGITS="4"
fi

# Find the highest existing ID in board.md
# Pattern: BUG-XXXX where XXXX is zero-padded digits
HIGHEST=$(grep -oE "${PREFIX}-[0-9]{${DIGITS}}" "$BOARD_FILE" 2>/dev/null \
  | sed "s/${PREFIX}-//" \
  | sort -n \
  | tail -1 \
  || true)

if [ -z "$HIGHEST" ]; then
  NEXT=1
else
  # Strip leading zeros for arithmetic
  NEXT=$(( 10#${HIGHEST} + 1 ))
fi

# Zero-pad to configured digits
printf "%s-%0${DIGITS}d\n" "$PREFIX" "$NEXT"
exit 0
