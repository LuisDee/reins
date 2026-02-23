#!/usr/bin/env bash
set -euo pipefail

# bugboard-init.sh — Initialises .bugboard/ structure in the current project.
# Idempotent: safe to run multiple times.
#
# Usage: bash scripts/bugboard-init.sh [project-dir]
#   project-dir defaults to current working directory

PROJECT_DIR="${1:-.}"
BUGBOARD_DIR="${PROJECT_DIR}/.bugboard"

# Resolve the template directory relative to this script
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/../templates/bugboard"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: template directory not found at ${TEMPLATE_DIR}" >&2
  exit 1
fi

# Create directory structure
mkdir -p "${BUGBOARD_DIR}/bugs"
mkdir -p "${BUGBOARD_DIR}/archive"

# Copy templates if they don't already exist (idempotent)
if [ ! -f "${BUGBOARD_DIR}/board.md" ]; then
  cp "${TEMPLATE_DIR}/board.md" "${BUGBOARD_DIR}/board.md"
fi

if [ ! -f "${BUGBOARD_DIR}/config.json" ]; then
  cp "${TEMPLATE_DIR}/config.json" "${BUGBOARD_DIR}/config.json"
fi

echo ".bugboard/ initialised in ${PROJECT_DIR}"
exit 0
