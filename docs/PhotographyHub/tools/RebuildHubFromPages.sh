#!/bin/bash
set -euo pipefail

LOG="$HOME/Desktop/HubBuildSync.log"
exec > >(tee -a "$LOG") 2>&1
echo "=== Hub build started: $(date) ==="
echo "SCRIPT: $0"

ROOT="/Volumes/Extreme SSD/Backup_Files_To_NAS/PhotographyHub"
PAGES="$ROOT/pages"
HUB="$ROOT/index.html"

# Collect "slug|title" lines here, then sort
tmp_cards="$(mktemp)"
trap 'rm -f "$tmp_cards"' EXIT

SLUGS="|"   # delimiter-wrapped list to test membership

# Helper: prettify a slug to Title Case
to_title() {
  echo "$1" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++){ $i=toupper(substr($i,1,1)) substr($i,2) }}1'
}

# Iterate pages (skip if none)
found_any=false
for f in "$PAGES"/*.html; do
  [ -e "$f" ] || break
  found_any=true

  base="$(basename "$f")"
  slug="${base%.html}"

  # Skip templates, master variants, AppleDouble
  case "$base" in
    ._*|template.html|MASTER.html|MASTER-*.html) continue ;;
  esac
  # Skip common duplicate patterns: "name (1).html", "name copy.html"
  case "$base" in
    *" ("[0-9]")".html|*[Cc]opy*.html) continue ;;
  esac

  # Deduplicate by slug (first wins)
  case "$SLUGS" in
    *"|$slug|"*) continue ;;
  esac
  SLUGS="${SLUGS}${slug}|"

  # Extract title from <h1> or <title>, else prettified slug
  title="$(sed -n 's:.*<h1[^>]*>\([^<][^<]*\)</h1>.*:\1:p' "$f" | head -1)"
  if [ -z "$title" ]; then
    title="$(sed -n 's:.*<title[^>]*>\([^<][^<]*\)</title>.*:\1:p' "$f" | head -1)"
  fi
  if [ -z "$title" ]; then
    title="$(to_title "$slug")"
  fi

  printf '%s|%s\n' "$slug" "$title" >> "$tmp_cards"
done

# Build index.html
{
  cat <<'HTML'
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Bridge Tools — Photography Workflow Hub</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    body{margin:24px;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Arial,sans-serif;background:#eef1f4;color:#101828}
    h1{margin:0 0 16px}
    .grid{max-width:1100px;margin:0 auto;display:grid;gap:16px;grid-template-columns:repeat(auto-fill,minmax(280px,1fr))}
    .card{background:#fff;border-radius:14px;padding:16px 16px 18px;box-shadow:0 6px 18px rgba(16,24,40,.08)}
    .card h2{margin:0 0 6px;font-size:18px}
    .card p{margin:0 0 10px;color:#475467}
    a{color:#0e49c2;text-decoration:none} a:hover{text-decoration:underline}
  </style>
</head>
  <body>
  <h1>Bridge Tools — Photography Workflow Hub</h1>
  <p class="stamp">Edits happen on the SanDisk. Build syncs to iCloud. iPhone reads the iCloud mirror.</p>
  <div class="grid">
HTML

  if [ -s "$tmp_cards" ]; then
    sort -f "$tmp_cards" | while IFS='|' read -r slug title; do
      printf '    <div class="card"><h2><a href="pages/%s.html">%s</a></h2><a href="pages/%s.html">Open →</a></div>\n' \
        "$slug" "$title" "$slug"
    done
  fi

  cat <<'HTML'
  </div>
</body>
</html>
HTML
} > "$HUB"

echo "Rebuilt hub: $HUB"

# ------------------------------------------------------------
# Mirror Hub to iCloud Drive for iPhone viewing
# (Keeps the same structure: index.html + pages/)
# ------------------------------------------------------------

ICLOUD_ROOT="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
ICLOUD_HUB="$ICLOUD_ROOT/Photography_Workflow"

# SanDisk hub folder (already defined as ROOT above)
SRC_HUB="$ROOT"

# Ensure iCloud Drive path exists
mkdir -p "$ICLOUD_HUB"

# Mirror: make iCloud copy match SanDisk copy exactly
# --delete removes files in iCloud that were deleted from SanDisk hub
# Exclude macOS metadata files
rsync -a --delete \
  --exclude ".DS_Store" \
  --exclude "._*" \
  --exclude ".Spotlight-V100" \
  --exclude ".Trashes" \
  "$SRC_HUB/" "$ICLOUD_HUB/"

echo "Mirrored hub to iCloud: $ICLOUD_HUB"

# Optional nice touch: open the iCloud hub in your default browser
open "$ICLOUD_HUB/index.html"