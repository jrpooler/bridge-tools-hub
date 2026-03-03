#!/usr/bin/env bash
set -euo pipefail

VOLUME="Extreme SSD"
SRC="/Volumes/${VOLUME}/Backup_Files_To_NAS/PhotographyHub"
ICLOUD_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
DST="$ICLOUD_ROOT/Photography_Workflow"

echo "Source: $SRC"
echo "iCloud Dest: $DST"

# 1) sanity checks
[[ -d "$SRC" ]] || { echo "ERROR: Source hub not found: $SRC"; exit 1; }
[[ -f "$SRC/index.html" ]] || { echo "ERROR: Source index.html not found: $SRC/index.html"; exit 1; }

# 2) ensure destination exists
mkdir -p "$DST"

# 3) mirror hub
rsync -a --delete \
  --exclude ".DS_Store" \
  --exclude "._*" \
  --exclude ".Spotlight-V100" \
  --exclude ".Trashes" \
  "$SRC/" "$DST/"

# 4) iPhone cleanup: remove common confusing artifacts
find "$DST" -maxdepth 1 -type f \( -name "*.bak" -o -name "*.bak*" -o -name "* alias" \) -print -delete 2>/dev/null || true

# 5) ensure real index.html exists (not empty)
if [[ ! -s "$DST/index.html" ]]; then
  echo "ERROR: iCloud index.html is missing or empty after sync."
  exit 1
fi

echo "OK: iCloud hub is iPhone-ready."
echo "Open on iPhone: Files → iCloud Drive → Photography_Workflow → index.html"
