BEGIN { inlist = 0; p = "" }
function esc(s) { gsub(/&/,"&amp;",s); gsub(/</,"&lt;",s); gsub(/>/,"&gt;",s); return s }
function outpara() { if (p!="") { print "<p>" p "</p>"; p="" } }
function closeul() { if (inlist) { print "</ul>"; inlist=0 } }

# Skip metadata lines
/^@@[ \t]/ { next }

# Headings
/^###[ \t]+/ { closeul(); outpara(); line=$0; sub(/^###[ \t]+/,"",line); print "<h3>" esc(line) "</h3>"; next }
/^##[ \t]+/  { closeul(); outpara(); line=$0; sub(/^##[ \t]+/,"",line);  print "<h2>" esc(line) "</h2>"; next }
(/^#[ \t]+/ && !/^##/) { closeul(); outpara(); line=$0; sub(/^#[ \t]+/,"",line); print "<h1>" esc(line) "</h1>"; next }

# Bullets
/^[ \t]*-[ \t]+/ {
  outpara()
  if (!inlist) { print "<ul>"; inlist=1 }
  line=$0; sub(/^[ \t]*-[ \t]+/,"",line)
  print "<li>" esc(line) "</li>"
  next
}

# Blank line
/^[ \t]*$/ { closeul(); outpara(); next }

# Normal text → paragraphs (join soft-wrapped lines)
{
  line = esc($0)
  if (p=="") p=line; else p=p " " line
}

END { closeul(); outpara() }
