#!/usr/bin/env bash
set -euo pipefail
echo "RUNNING SCRIPT: $0"
# ====== CONFIG ======
VOLUME="Extreme SSD"
HUB_ROOT="/Volumes/${VOLUME}/Backup_Files_To_NAS/PhotographyHub"
PAGES="$HUB_ROOT/pages"
TOOLS="$HUB_ROOT/tools"
MASTER="$PAGES/MASTER-steps.txt"
INDEX="$HUB_ROOT/index.html"
TMP_INDEX="$HUB_ROOT/.index.new.html"
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
TITLE="Bridge Tools — Photography Workflow Hub"
SYNC_NOTE="Edits happen on the SanDisk. Build syncs to iCloud. iPhone reads the iCloud mirror."
# ====================

ts(){ date "+%Y-%m-%d %H:%M:%S"; }

echo "[$(ts)] Build starting…"
[[ -d "/Volumes/${VOLUME}" ]] || { echo "[$(ts)] ERROR: SanDisk not mounted at /Volumes/${VOLUME}"; exit 1; }
[[ -f "$MASTER" ]] || { echo "[$(ts)] ERROR: MASTER file not found: $MASTER"; exit 1; }
mkdir -p "$PAGES" "$TOOLS"

# 1) Clean previously generated .html pages (keep template.html if present)
echo "[$(ts)] Cleaning old generated pages…"
find "$PAGES" -type f -name '*.html' ! -name 'template.html' -delete 2>/dev/null || true

# 2) Parse MASTER and generate per-page HTMLs + collect card metadata
META_TMP="$(mktemp)"
trap 'rm -f "$META_TMP"' EXIT

/usr/bin/awk -v PAGES_DIR="$PAGES" -v META="$META_TMP" '
function html_escape(s,   t){ t=s; gsub("&","&amp;",t); gsub("<","&lt;",t); gsub(">","&gt;",t); return t }
function trim(s){ sub(/^[ \t\r\n]+/,"",s); sub(/[ \t\r\n]+$/,"",s); return s }
function slugify(s,   t){ t=tolower(s); gsub(/[^a-z0-9]+/,"-",t); gsub(/^-+|-+$/,"",t); if (t=="") t="untitled"; return t }
function summarize(txt,   t){ t=txt; gsub(/\r/,"",t); gsub(/\n+/," ",t); sub(/^[ \t]+/,"",t); if (length(t)>180) t=substr(t,1,177)"…"; return t }
function end_para(){ if (para!=""){ body_html = body_html "<p>" para "</p>\n"; para="" } }
function emit(   out,esc_title,i,n,line,item,inlist){
  if (title=="") return
  if (slug=="") slug = slugify(title)
  if (order=="") order="999"
  if (back=="") back="../index.html"
  if (summary=="") summary = summarize(body)

  body_html=""; para=""; inlist=0
  n=split(body, L, "\n")
  for (i=1; i<=n; i++){
    line=L[i]
    # blank line => close paragraph or list
    if (line ~ /^[ \t]*$/){
      if (inlist){ body_html = body_html "</ul>\n"; inlist=0 }
      end_para()
      continue
    }
    # bullet list line starting with "- "
    if (line ~ /^[ \t]*-[ \t]+/){
      if (!inlist){ end_para(); body_html = body_html "<ul>\n"; inlist=1 }
      item=line
      sub(/^[ \t]*-[ \t]+/,"",item)
      body_html = body_html "<li>" html_escape(item) "</li>\n"
      continue
    }
    # normal text
    if (inlist){ body_html = body_html "</ul>\n"; inlist=0 }
    if (para!="") para = para " "
    para = para html_escape(line)
  }
  if (inlist){ body_html = body_html "</ul>\n" }
  end_para()

  esc_title = html_escape(title)
  out = PAGES_DIR "/" slug ".html"

  print "<!doctype html>" > out
  print "<html lang=\"en\">" >> out
  print "<head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" >> out
  print "<title>" esc_title "</title>" >> out
  print "<style>body{margin:24px;font:16px/1.6 -apple-system,BlinkMacSystemFont,\"Segoe UI\",Arial,sans-serif;background:#eef1f4;color:#101828}a{color:#0e49c2;text-decoration:none}a:hover{text-decoration:underline}.wrap{max-width:900px;margin:0 auto}.card{background:#fff;border-radius:14px;padding:20px;box-shadow:0 6px 18px rgba(16,24,40,.08)}.back{margin:0 0 16px;display:inline-block}</style>" >> out
  print "</head><body><div class=\"wrap\">" >> out

  # Back link: go back if possible, else to the hub. Use &larr; for the arrow.
  # print "<a class=\"back\" href=\"#\" onclick=\"if(history.length>1){history.back();}else{window.location.href='../index.html';}return false;\">&larr; Back</a>" >> out

  print "<div class=\"card\"><h1>" esc_title "</h1>" >> out
  printf "%s", body_html >> out
  print "</div></div></body></html>" >> out
  close(out)

  # metadata line for index
  s = summary
  gsub(/\|/," - ",s)
  print order "|" slug "|" title "|" s >> META
}
BEGIN{
  title=slug=summary=order=back=body=""
}
# metadata lines
/^@@[ \t]*title[ \t]*:/{
  emit()
  title=$0; sub(/^@@[ \t]*title[ \t]*:/,"",title); title=trim(title)
  slug=summary=order=back=""; body=""
  next
}
/^@@[ \t]*slug[ \t]*:/    { slug=$0;    sub(/^@@[ \t]*slug[ \t]*:/,"",slug);       slug=trim(slug);    next }
/^@@[ \t]*summary[ \t]*:/ { summary=$0; sub(/^@@[ \t]*summary[ \t]*:/,"",summary); summary=trim(summary); next }
/^@@[ \t]*order[ \t]*:/   { order=$0;   sub(/^@@[ \t]*order[ \t]*:/,"",order);     order=trim(order);   next }
/^@@[ \t]*back[ \t]*:/    { back=$0;    sub(/^@@[ \t]*back[ \t]*:/,"",back);       back=trim(back);    next }
# body
{ body = body $0 "\n" }
END{ emit() }
' "$MASTER"

# 3) Build index.html from metadata (sorted by order), open cards in new tab, add “Last built”
echo "[$(ts)] Writing index…"

{
  cat <<HTML_HEAD
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>$TITLE</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    :root { --bg:#eef1f4; --fg:#101828; --card:#fff; --accent:#0e49c2; --muted:#475467; }
    body{margin:24px;font:16px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Arial,sans-serif;background:var(--bg);color:var(--fg)}
    h1{margin:0 0 8px}
    .stamp{margin:0 0 16px;color:#6b7280;font-size:.95rem}
    .grid{max-width:1100px;margin:0 auto;display:grid;gap:16px;grid-template-columns:repeat(auto-fill,minmax(280px,1fr))}
    .card{background:var(--card);border-radius:14px;padding:16px 16px 18px;box-shadow:0 6px 18px rgba(16,24,40,.08)}
    .card h2{margin:0 0 6px;font-size:18px}
    .card p{margin:0 0 10px;color:var(--muted)}
    a{color:#0e49c2;text-decoration:none} a:hover{text-decoration:underline}
  </style>
</head>
<body>
  <h1>$TITLE</h1>
  <div class="stamp">$SYNC_NOTE</div>
  <div class="stamp">Last built: $STAMP</div>
  <div class="grid">
HTML_HEAD

  sort -t"|" -k1,1n "$META_TMP" | while IFS="|" read -r ord slug title summary; do
    esc_title=${title//&/&amp;}; esc_title=${esc_title//</&lt;}; esc_title=${esc_title//>/&gt;}
    esc_summary=${summary//&/&amp;}; esc_summary=${esc_summary//</&lt;}; esc_summary=${esc_summary//>/&gt;}
    printf '    <div class="card"><h2><a href="pages/%s.html" >%s</a></h2><p>%s</p><a href="pages/%s.html" >Open →</a></div>\n' \
      "$slug" "$esc_title" "$esc_summary" "$slug"
  done

  cat <<HTML_TAIL
  </div>
</body>
</html>
HTML_TAIL
TMP_INDEX="$HUB_ROOT/.index.new.html"
} > "$TMP_INDEX"

if [[ -s "$TMP_INDEX" ]]; then
  mv "$TMP_INDEX" "$INDEX"
else
  echo "[$(ts)] ERROR: Generated index was empty; keeping previous index.html"
  rm -f "$TMP_INDEX"
  exit 1
fi

# 4) Inject Tools panel under the H1 (if fragment exists)
TOOLS_FRAG="$TOOLS/hub_tools.html"
if [[ -f "$TOOLS_FRAG" && -f "$INDEX" ]]; then
  echo "[$(ts)] Injecting tools panel…"
  tmp="$HUB_ROOT/.index.tmp"
  awk -v frag="$TOOLS_FRAG" '
  {
    print $0
    if ($0 ~ /<h1>/ && inserted==0) {
      system("cat \"" frag "\"")
      inserted=1
    }
  }
' "$INDEX" > "$tmp" && mv "$tmp" "$INDEX"
fi

echo "[$(ts)] Build complete."
# Prefer Safari for file:// .command links
open -a "Safari" "$INDEX" 2>/dev/null || open "$INDEX" 2>/dev/null || true
# ------------------------------------------------------------
# Sync hub to iCloud for iPhone access
# ------------------------------------------------------------

SYNC_SCRIPT="$TOOLS/SyncHubToiCloudForiPhone.sh"

if [[ -x "$SYNC_SCRIPT" ]]; then
  echo "[$(ts)] Syncing hub to iCloud for iPhone..."
  "$SYNC_SCRIPT"
else
  echo "[$(ts)] WARNING: SyncHubToiCloudForiPhone.sh not found or not executable."
fi