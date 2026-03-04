#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MASTER="$ROOT_DIR/docs/PhotographyHub/pages/MASTER-steps.txt"
TOOLS_FRAGMENT="$ROOT_DIR/docs/PhotographyHub/tools/hub_tools.html"
DOCS_DIR="$ROOT_DIR/docs"
PAGES_DIR="$DOCS_DIR/pages"
INDEX_FILE="$DOCS_DIR/index.html"
STAMP="$(date '+%Y-%m-%d %H:%M:%S %Z')"
TITLE="Bridge Tools — Photography Workflow Hub"
SYNC_NOTE="Edits happen on the SanDisk. Build syncs to iCloud. iPhone reads the iCloud mirror."

if [[ ! -f "$MASTER" ]]; then
  echo "ERROR: MASTER file not found: $MASTER" >&2
  exit 1
fi

mkdir -p "$PAGES_DIR"
find "$PAGES_DIR" -type f -name '*.html' -delete

meta_tmp="$(mktemp)"
trap 'rm -f "$meta_tmp"' EXIT

awk -v PAGES_DIR="$PAGES_DIR" -v META="$meta_tmp" '
function html_escape(s,   t){ t=s; gsub("&","&amp;",t); gsub("<","&lt;",t); gsub(">","&gt;",t); return t }
function trim(s){ sub(/^[ \t\r\n]+/,"",s); sub(/[ \t\r\n]+$/,"",s); return s }
function slugify(s,   t){ t=tolower(s); gsub(/[^a-z0-9]+/,"-",t); gsub(/^-+|-+$/,"",t); if (t=="") t="untitled"; return t }
function summarize(txt,   t){ t=txt; gsub(/\r/,"",t); gsub(/\n+/," ",t); sub(/^[ \t]+/,"",t); if (length(t)>180) t=substr(t,1,177)"..."; return t }
function write_para(){ if (para!=""){ body_html = body_html "<p>" para "</p>\n"; para="" } }
function close_list(){ if (inlist){ body_html = body_html "</ul>\n"; inlist=0 } }
function emit(   out,esc_title,n,i,line,item,level,htext,s){
  if (title=="") return
  if (slug=="") slug = slugify(title)
  if (order=="") order="999"
  if (summary=="") summary = summarize(body)

  body_html=""; para=""; inlist=0
  n=split(body, L, "\n")
  for (i=1; i<=n; i++){
    line=L[i]

    if (line ~ /^[ \t]*$/){
      close_list()
      write_para()
      continue
    }

    if (line ~ /^[ \t]*#[#]*[ \t]+/){
      close_list()
      write_para()
      level=1
      while (substr(line,level+1,1)=="#") level++
      if (level > 3) level = 3
      htext=line
      sub(/^[ \t]*#[#]*[ \t]+/,"",htext)
      body_html = body_html "<h" (level+1) ">" html_escape(htext) "</h" (level+1) ">\n"
      continue
    }

    if (line ~ /^[ \t]*-[ \t]+/){
      write_para()
      if (!inlist){ body_html = body_html "<ul>\n"; inlist=1 }
      item=line
      sub(/^[ \t]*-[ \t]+/,"",item)
      body_html = body_html "<li>" html_escape(item) "</li>\n"
      continue
    }

    close_list()
    if (para!="") para = para " "
    para = para html_escape(line)
  }

  close_list()
  write_para()

  esc_title = html_escape(title)
  out = PAGES_DIR "/" slug ".html"

  print "<!doctype html>" > out
  print "<html lang=\"en\">" >> out
  print "<head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">" >> out
  print "<title>" esc_title "</title>" >> out
  print "<style>body{margin:24px;font:16px/1.6 -apple-system,BlinkMacSystemFont,\"Segoe UI\",Arial,sans-serif;background:#eef1f4;color:#101828}a{color:#0e49c2;text-decoration:none}a:hover{text-decoration:underline}.wrap{max-width:900px;margin:0 auto}.card{background:#fff;border-radius:14px;padding:20px;box-shadow:0 6px 18px rgba(16,24,40,.08)}.back{margin:0 0 16px;display:inline-block}h2,h3,h4{margin:1rem 0 .5rem}ul{margin:.4rem 0 1rem 1.2rem}</style>" >> out
  print "</head><body><div class=\"wrap\">" >> out
  print "<a class=\"back\" href=\"../index.html\">&larr; Back to Hub</a>" >> out
  print "<div class=\"card\"><h1>" esc_title "</h1>" >> out
  printf "%s", body_html >> out
  print "</div></div></body></html>" >> out
  close(out)

  s = summary
  gsub(/\|/," - ",s)
  print order "|" slug "|" title "|" s >> META
}
BEGIN{
  title=slug=summary=order=body=""
}
/^@@[ \t]*title[ \t]*:/{
  emit()
  title=$0; sub(/^@@[ \t]*title[ \t]*:/,"",title); title=trim(title)
  slug=summary=order=""; body=""
  next
}
/^@@[ \t]*slug[ \t]*:/    { slug=$0;    sub(/^@@[ \t]*slug[ \t]*:/,"",slug);       slug=trim(slug);    next }
/^@@[ \t]*summary[ \t]*:/ { summary=$0; sub(/^@@[ \t]*summary[ \t]*:/,"",summary); summary=trim(summary); next }
/^@@[ \t]*order[ \t]*:/   { order=$0;   sub(/^@@[ \t]*order[ \t]*:/,"",order);     order=trim(order);   next }
/^@@[ \t]*back[ \t]*:/    { next }
{ body = body $0 "\n" }
END{ emit() }
' "$MASTER"

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
HTML_HEAD

  if [[ -f "$TOOLS_FRAGMENT" ]]; then
    cat "$TOOLS_FRAGMENT"
  fi

  cat <<HTML_MID
  <div class="stamp">$SYNC_NOTE</div>
  <div class="stamp">Last built: $STAMP</div>
  <div class="grid">
HTML_MID

  sort -t'|' -k1,1n "$meta_tmp" | while IFS='|' read -r ord slug title summary; do
    esc_title=${title//&/&amp;}; esc_title=${esc_title//</&lt;}; esc_title=${esc_title//>/&gt;}
    esc_summary=${summary//&/&amp;}; esc_summary=${esc_summary//</&lt;}; esc_summary=${esc_summary//>/&gt;}
    printf '    <div class="card"><h2><a href="pages/%s.html">%s</a></h2><p>%s</p><a href="pages/%s.html">Open -></a></div>\n' \
      "$slug" "$esc_title" "$esc_summary" "$slug"
  done

  cat <<'HTML_TAIL'
  </div>
</body>
</html>
HTML_TAIL
} > "$INDEX_FILE"

echo "Built site root: $INDEX_FILE"
echo "Built pages dir: $PAGES_DIR"
