#!/usr/bin/env python3
"""Summarize a pa11y-ci JSON report and exit 0 (clean), 2 (findings) or 1 (bad report)."""

import json
import sys


def main() -> None:
    path = sys.argv[1]
    try:
        with open(path, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: could not read the pa11y-ci report: {exc}", file=sys.stderr)
        sys.exit(1)

    results = data.get("results") or {}
    total = data.get("total")
    passes = data.get("passes")
    if not isinstance(total, int):
        total = len(results)
    if not isinstance(passes, int):
        passes = sum(1 for issues in results.values() if not issues)

    issues_by_code = {}
    page_errors = []
    for url, issues in results.items():
        if not isinstance(issues, list):
            page_errors.append((url, str(issues)))
            continue
        for issue in issues:
            if not isinstance(issue, dict) or "code" not in issue:
                message = issue.get("message", str(issue)) if isinstance(issue, dict) else str(issue)
                page_errors.append((url, message))
                continue
            code = issue["code"]
            entry = issues_by_code.setdefault(
                code,
                {"pages": set(), "nodes": 0, "help": "", "message": issue.get("message", "")},
            )
            entry["pages"].add(url)
            entry["nodes"] += 1
            help_url = (issue.get("runnerExtras") or {}).get("helpUrl")
            if help_url and not entry["help"]:
                entry["help"] = help_url

    print(f"{passes}/{total} pages passed")
    for code in sorted(issues_by_code, key=lambda value: (-len(issues_by_code[value]["pages"]), value)):
        entry = issues_by_code[code]
        print(f"- {code}: {len(entry['pages'])} page(s), {entry['nodes']} node(s)")
        if entry["help"]:
            print(f"  {entry['help']}")
        if code == "color-contrast":
            print("  contrast ratios are not in pa11y's axe output; read them with axe DevTools or `npx @axe-core/cli`")
    for url, message in page_errors:
        print(f"- {url}: {message}")

    sys.exit(2 if (issues_by_code or page_errors) else 0)


if __name__ == "__main__":
    main()
