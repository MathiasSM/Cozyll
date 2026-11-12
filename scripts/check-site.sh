#!/usr/bin/env bash
# Run the Cozyll site checks locally. The GitHub composite actions call the same
# subcommands, so local runs and CI use the same logic.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF'
Usage: check-site.sh <check> [options]

Checks (tools in parentheses):
  content-schema   Validate website.yaml, authors.yaml, socials.yaml and localization.yaml against the schemas. (pipx)
  html             Validate HTML, CSS and SVG with the W3C Nu checker. (java, curl)
  a11y             Audit the built site with pa11y-ci and the axe runner. (python3, npx, Chrome)
  links-external   Check external links with lychee. (lychee)
  xml              Validate that generated XML is well formed. (xmllint)
  jsonld           Validate JSON-LD blocks in generated HTML. (python3)
  wellknown        Validate well-known and metadata files. (python3)
  spelling         Run typos. (typos)
  all              Run the default CI set: content-schema, html, a11y, xml, jsonld,
                   wellknown. Exits 2 when the only findings are advisory a11y ones.

Options:
  --content-dir DIR   Content directory (default: content).
  --site-dir DIR      Built site directory (default: _site).
  --schema-dir DIR    Schema directory (default: schema).
  --port PORT         Port for the local a11y server (default: 8080).
  --standard STD      WCAG standard for pa11y (default: WCAG2AA).
  --a11y-fail BOOL    true fails on accessibility issues, false keeps exit 0, unset
                      leaves them advisory and `all` exits 2.
  --a11y-report FILE  Keep the raw pa11y-ci JSON report at FILE.
  --config FILE       Tool config file, where supported (lychee, typos).
  --vnu-jar FILE      Path to vnu.jar (default: VNU_JAR, else downloaded to the temp dir).
  --fail BOOL         For links-external: fail on broken links (default: false).
  -h, --help          Show this help.

Exit status for `all`: 0 when everything is clean, 1 when a hard check fails or
--a11y-fail true finds issues, 2 when the only findings are advisory a11y ones.
An explicit --a11y-fail false keeps 0. The standalone `a11y` check uses the same
mapping.

Tools are expected on PATH. A missing tool fails with an install hint. The optional
checks (links-external, spelling) are not part of `all`.

The a11y check runs pa11y-ci with the axe runner (the same configuration as CI);
bare `npx pa11y` defaults to HTML_CodeSniffer and will disagree. pa11y's axe runner
drops axe's contrast ratios, so read those with axe DevTools or `npx @axe-core/cli`.
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
a11y_fail=""
a11y_report=""
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
    --a11y-fail)
      [ "$#" -ge 2 ] || die "option --a11y-fail requires true or false"
      case "$2" in
        true|false) a11y_fail="$2" ;;
        *) die "--a11y-fail must be true or false" ;;
      esac
      shift 2 ;;
    --a11y-report)
      [ "$#" -ge 2 ] || die "option --a11y-report requires a file"
      a11y_report="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown argument: $1" ;;
  esac
done

[ -n "$check" ] || { usage; exit 2; }

run_content_schema() {
  need pipx "Install pipx, for example 'python3 -m pip install --user pipx'."
  local pair schema file
  for pair in website:website.yaml authors:authors.yaml socials:socials.yaml localization:localization.yaml; do
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

  local cfg report temp_report pid ready rc summary_rc
  cfg="$(mktemp)"
  if [ -n "$a11y_report" ]; then
    report="$a11y_report"
    temp_report=""
  else
    report="$(mktemp)"
    temp_report="$report"
  fi

  python3 -m http.server "$port" --bind 127.0.0.1 --directory "$site_dir" >/dev/null 2>&1 &
  pid=$!
  trap 'kill "$pid" 2>/dev/null || true; rm -f "$cfg"; if [ -n "$temp_report" ]; then rm -f "$temp_report"; fi' EXIT

  ready=0
  for _ in $(seq 1 40); do
    if curl -fsS -o /dev/null "http://127.0.0.1:$port/"; then
      ready=1
      break
    fi
    sleep 0.25
  done
  if [ "$ready" -ne 1 ]; then
    info "server did not start on port $port"
    exit 1
  fi

  python3 "$script_dir/a11y_config.py" "$site_dir" "$port" "$standard" > "$cfg"

  set +e
  npx --yes pa11y-ci --config "$cfg" --json > "$report"
  rc=$?
  set -e
  case "$rc" in
    0|2) ;;
    *)
      info "pa11y-ci failed with exit code $rc"
      exit 1
      ;;
  esac

  set +e
  python3 "$script_dir/a11y_report.py" "$report"
  summary_rc=$?
  set -e

  if [ -n "$a11y_report" ]; then
    info "pa11y-ci report: $report"
  fi

  if [ "$summary_rc" -eq 1 ]; then
    exit 1
  fi
  if [ "$summary_rc" -eq 2 ]; then
    case "$a11y_fail" in
      true) exit 1 ;;
      false) exit 0 ;;
      *) exit 2 ;;
    esac
  fi
  exit 0
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
  python3 "$script_dir/check_jsonld.py" "$site_dir"
}

run_wellknown() {
  need python3 "Install Python 3."
  local d="$site_dir"
  local fail=0
  local f
  for f in robots.txt manifest.webmanifest sitemap.xml .well-known/security.txt .well-known/trust.txt; do
    if [ ! -f "$d/$f" ]; then
      info "missing $d/$f"
      fail=1
    fi
  done
  if [ "$fail" -ne 0 ]; then
    exit 1
  fi
  grep -qi '^Contact:' "$d/.well-known/security.txt" || die "security.txt missing Contact"
  local exp when now
  exp="$(grep -i '^Expires:' "$d/.well-known/security.txt" | head -1 | cut -d: -f2- | xargs)"
  if [ -z "$exp" ]; then
    die "security.txt missing Expires"
  fi
  if ! when="$(date -u -d "$exp" +%s 2>/dev/null)"; then
    die "security.txt Expires is not ISO 8601: $exp"
  fi
  now="$(date -u +%s)"
  if [ "$when" -le "$now" ]; then
    die "security.txt Expires is in the past: $exp"
  fi
  python3 -m json.tool "$d/manifest.webmanifest" >/dev/null
  if [ -f "$d/funding.json" ]; then
    python3 -m json.tool "$d/funding.json" >/dev/null
  else
    info "no funding.json (no funding section); skipping"
  fi
}

run_spelling() {
  need typos "Install typos from https://github.com/crate-ci/typos."
  local args=()
  if [ -n "$config" ]; then
    args+=(--config "$config")
  fi
  typos "${args[@]}" "$content_dir"
}

# Runs one check in a subshell and records its status, so `all` can finish the
# remaining checks and print a summary. Accessibility status 2 is advisory.
summary=()
all_hard=0
all_advisory=0

run_all_check() {
  local name="$1"
  shift
  local status=0
  ( "$@" ) || status=$?
  if [ "$status" -eq 0 ]; then
    summary+=("$name: ok")
    return 0
  fi
  if [ "$name" = "a11y" ] && [ "$status" -eq 2 ]; then
    summary+=("$name: advisory findings")
    all_advisory=1
    return 0
  fi
  summary+=("$name: FAILED")
  all_hard=1
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
    run_all_check content-schema run_content_schema
    run_all_check html run_html
    run_all_check a11y run_a11y
    run_all_check xml run_xml
    run_all_check jsonld run_jsonld
    run_all_check wellknown run_wellknown

    printf '\nSummary:\n'
    for line in "${summary[@]}"; do
      printf '  %s\n' "$line"
    done

    if [ "$all_hard" -ne 0 ]; then
      exit 1
    fi
    if [ "$all_advisory" -ne 0 ]; then
      exit 2
    fi
    exit 0
    ;;
esac
