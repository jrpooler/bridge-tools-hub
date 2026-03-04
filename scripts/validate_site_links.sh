#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOCS_DIR="$ROOT_DIR/docs"
INDEX_FILE="$DOCS_DIR/index.html"
PAGES_DIR="$DOCS_DIR/pages"

fail() {
  echo "ERROR: $1" >&2
  exit 1
}

[[ -s "$INDEX_FILE" ]] || fail "Missing or empty $INDEX_FILE"
[[ -d "$PAGES_DIR" ]] || fail "Missing pages directory: $PAGES_DIR"

card_links=()
while IFS= read -r link; do
  card_links+=("$link")
done < <(grep -oE 'href="pages/[^"]+\.html"' "$INDEX_FILE" | sed -E 's/^href="([^"]+)"$/\1/' | sort -u)

[[ ${#card_links[@]} -gt 0 ]] || fail "No card links found in $INDEX_FILE"

for link in "${card_links[@]}"; do
  target="$DOCS_DIR/$link"
  [[ -f "$target" ]] || fail "Card link target missing: $link"
done

shopt -s nullglob
page_files=("$PAGES_DIR"/*.html)
shopt -u nullglob

[[ ${#page_files[@]} -gt 0 ]] || fail "No generated page files found in $PAGES_DIR"

for page in "${page_files[@]}"; do
  grep -qE "href=\"\\.\\./index\\.html\"|href='\\.\\./index\\.html'" "$page" || fail "Missing back link to ../index.html in $(basename "$page")"
done

echo "Link validation passed."
echo "- Index: $INDEX_FILE"
echo "- Cards found: ${#card_links[@]}"
echo "- Pages checked: ${#page_files[@]}"
