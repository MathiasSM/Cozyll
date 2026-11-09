#!/usr/bin/env bash
# Run the Cozyll site checks locally. The GitHub composite actions call the same
# subcommands, so local runs and CI use the same logic.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: check-site.sh <check> [options]

Checks (tools in parentheses):
  content-schema   Validate website.yaml, authors.yaml and socials.yaml against the schemas. (pipx)
  html             Validate HTML, CSS and SVG with the W3C Nu checker. (java, curl)
  a11y             Audit the built site with pa11y-ci and axe. (python3, npx, Chrome)
  links-external   Check external links with lychee. (lychee)
  xml              Validate that generated XML is well formed. (xmllint)
  jsonld           Validate JSON-LD blocks in generated HTML. (python3)
  wellknown        Validate well-known and metadata files. (python3)
  spelling         Run typos. (typos)
  all              Run the default CI set: content-schema, html, a11y, xml, jsonld, wellknown.

Options:
  --content-dir DIR   Content directory (default: content).
  --site-dir DIR      Built site directory (default: _site).
  --schema-dir DIR    Schema directory (default: schema).
  --port PORT         Port for the local a11y server (default: 8080).
  --standard STD      WCAG standard for pa11y (default: WCAG2AA).
  --config FILE       Tool config file, where supported (lychee, typos).
  --vnu-jar FILE      Path to vnu.jar (default: VNU_JAR, else downloaded to the temp dir).
  --fail BOOL         For links-external: fail on broken links (default: false).
  -h, --help          Show this help.

Tools are expected on PATH. A missing tool fails with an install hint. The optional
checks (links-external, spelling) are not part of `all`.
EOF
}

die() { printf 'error: %s\n' "$*" >&2; exit 1; }
info() { printf '%s\n' "$*" >&2; }
need() { command -v "$1" >/dev/null 2>&1 || die "missing '$1'. $2"; }

content_dir="content"
site_dir="_site"
schema_dir="schema"
port="8080"
standard="WCAG2AA"
config=""
vnu_jar="${VNU_JAR:-}"
fail_links="false"
check=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    content-schema|html|a11y|links-external|xml|jsonld|wellknown|spelling|all)
      check="$1"; shift ;;
    --content-dir) content_dir="$2"; shift 2 ;;
    --site-dir) site_dir="$2"; shift 2 ;;
    --schema-dir) schema_dir="$2"; shift 2 ;;
    --port) port="$2"; shift 2 ;;
    --standard) standard="$2"; shift 2 ;;
    --config) config="$2"; shift 2 ;;
    --vnu-jar) vnu_jar="$2"; shift 2 ;;
    --fail) fail_links="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$check" ] || { usage; exit 2; }

run_content_schema() {
  need pipx "Install pipx, for example 'python3 -m pip install --user pipx'."
  local pair schema file
  for pair in website:website.yaml authors:authors.yaml socials:socials.yaml; do
    schema="${pair%%:*}"
    file="${pair##*:}"
    if [ -f "$content_dir/$file" ]; then
      info "validating $content_dir/$file against $schema.schema.json"
      pipx run check-jsonschema \
        --schemafile "$schema_dir/$schema.schema.json" \
        "$content_dir/$file"
    else
      info "skipping missing $content_dir/$file"
    fi
  done
}

fetch_vnu() {
  if [ -n "$vnu_jar" ] && [ -f "$vnu_jar" ]; then
    return 0
  fi
  vnu_jar="${vnu_jar:-${TMPDIR:-/tmp}/vnu.jar}"
  info "downloading vnu.jar to $vnu_jar"
  curl -fsSL -o "$vnu_jar" https://github.com/validator/validator/releases/latest/download/vnu.jar
  curl -fsSL -o "$vnu_jar.sha1" https://github.com/validator/validator/releases/latest/download/vnu.jar.sha1
  ( cd "$(dirname "$vnu_jar")" && sha1sum -c "$(basename "$vnu_jar").sha1" )
}

run_html() {
  need java "Install a JRE, for example temurin-17."
  need curl "Install curl."
  fetch_vnu
  java -jar "$vnu_jar" \
    --skip-non-html --also-check-css --also-check-svg --errors-only \
    "$site_dir"
}

run_a11y() {
  need python3 "Install Python 3."
  need npx "Install Node.js."
  (
    cfg="$(mktemp)"
    python3 -m http.server "$port" --bind 127.0.0.1 --directory "$site_dir" >/dev/null 2>&1 &
    pid=$!
    trap 'kill "$pid" 2>/dev/null || true; rm -f "$cfg"' EXIT
    ready=0
    for _ in $(seq 1 40); do
      if curl -fsS -o /dev/null "http://127.0.0.1:$port/"; then
        ready=1
        break
      fi
      sleep 0.25
    done
    if [ "$ready" -ne 1 ]; then
      echo "server did not start on port $port" >&2
      exit 1
    fi
    python3 - "$site_dir" "$port" "$standard" > "$cfg" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
port = sys.argv[2]
standard = sys.argv[3]
urls = []
for page in sorted(root.rglob("*.html")):
    rel = page.relative_to(root).as_posix()
    if rel.endswith("index.html"):
        rel = rel[: -len("index.html")]
    urls.append(f"http://127.0.0.1:{port}/{rel}")
json.dump(
    {
        "defaults": {
            "standard": standard,
            "runners": ["axe"],
            "chromeLaunchConfig": {"args": ["--no-sandbox"]},
        },
        "urls": urls,
    },
    sys.stdout,
)
PY
    npx --yes pa11y-ci --config "$cfg"
  )
}

run_links_external() {
  need lychee "Install lychee from https://github.com/lycheeverse/lychee."
  local args=(--no-progress)
  if [ -n "$config" ]; then
    args+=(--config "$config")
  fi
  if lychee "${args[@]}" "$site_dir"; then
    return 0
  fi
  if [ "$fail_links" = "true" ]; then
    exit 1
  fi
  info "external links reported issues (advisory; pass --fail true to gate)"
}

run_xml() {
  need xmllint "Install libxml2-utils."
  if find "$site_dir" -type f -name '*.xml' | grep -q .; then
    find "$site_dir" -type f -name '*.xml' -print0 | xargs -0 xmllint --noout
  else
    info "no XML files found in $site_dir"
  fi
}

run_jsonld() {
  need python3 "Install Python 3."
  python3 - "$site_dir" <<'PY'
import json, pathlib, re, sys
root = pathlib.Path(sys.argv[1])
pattern = re.compile(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', re.S | re.I)
failures = []
count = 0
for html in root.rglob("*.html"):
    text = html.read_text(encoding="utf-8")
    for i, block in enumerate(pattern.findall(text), start=1):
        count += 1
        try:
            data = json.loads(block)
        except json.JSONDecodeError as exc:
            failures.append(f"{html}: block {i}: invalid JSON: {exc}")
            continue
        if "@context" not in data:
            failures.append(f"{html}: block {i}: missing @context")
        if "@type" not in data and "@graph" not in data:
            failures.append(f"{html}: block {i}: missing @type or @graph")
if failures:
    print("\n".join(failures))
    sys.exit(1)
print(f"validated {count} JSON-LD blocks")
PY
}

run_wellknown() {
  need python3 "Install Python 3."
  local d="$site_dir"
  local fail=0
  local f
  for f in robots.txt manifest.webmanifest funding.json sitemap.xml .well-known/security.txt .well-known/trust.txt; do
    if [ ! -f "$d/$f" ]; then
      info "missing $d/$f"
      fail=1
    fi
  done
  if [ "$fail" -ne 0 ]; then
    exit 1
  fi
  grep -qi '^Contact:' "$d/.well-known/security.txt" || die "security.txt missing Contact"
  local exp
  exp="$(grep -i '^Expires:' "$d/.well-known/security.txt" | head -1 | cut -d: -f2- | xargs)"
  python3 - "$exp" <<'PY'
import sys
from datetime import datetime, timezone
raw = sys.argv[1].strip()
if not raw:
    print("security.txt missing Expires")
    sys.exit(1)
try:
    when = datetime.fromisoformat(raw.replace("Z", "+00:00"))
except ValueError as exc:
    print(f"security.txt Expires is not ISO 8601: {raw} ({exc})")
    sys.exit(1)
if when <= datetime.now(timezone.utc):
    print(f"security.txt Expires is in the past: {raw}")
    sys.exit(1)
PY
  python3 - "$d/manifest.webmanifest" "$d/funding.json" <<'PY'
import json, sys
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as fh:
        json.load(fh)
PY
}

run_spelling() {
  need typos "Install typos from https://github.com/crate-ci/typos."
  local args=()
  if [ -n "$config" ]; then
    args+=(--config "$config")
  fi
  typos "${args[@]}" "$content_dir"
}

case "$check" in
  content-schema) run_content_schema ;;
  html) run_html ;;
  a11y) run_a11y ;;
  links-external) run_links_external ;;
  xml) run_xml ;;
  jsonld) run_jsonld ;;
  wellknown) run_wellknown ;;
  spelling) run_spelling ;;
  all)
    run_content_schema
    run_html
    run_a11y
    run_xml
    run_jsonld
    run_wellknown
    ;;
esac
