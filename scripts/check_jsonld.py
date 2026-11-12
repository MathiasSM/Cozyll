#!/usr/bin/env python3
"""Validate the JSON-LD blocks in the generated HTML under a site directory."""

import json
import pathlib
import re
import sys


def main() -> None:
    root = pathlib.Path(sys.argv[1])
    pattern = re.compile(r'<script[^>]*type="application/ld\+json"[^>]*>(.*?)</script>', re.S | re.I)
    failures = []
    count = 0
    for html in root.rglob("*.html"):
        text = html.read_text(encoding="utf-8")
        for index, block in enumerate(pattern.findall(text), start=1):
            count += 1
            try:
                data = json.loads(block)
            except json.JSONDecodeError as exc:
                failures.append(f"{html}: block {index}: invalid JSON: {exc}")
                continue
            if "@context" not in data:
                failures.append(f"{html}: block {index}: missing @context")
            if "@type" not in data and "@graph" not in data:
                failures.append(f"{html}: block {index}: missing @type or @graph")
    if failures:
        print("\n".join(failures))
        sys.exit(1)
    print(f"validated {count} JSON-LD blocks")


if __name__ == "__main__":
    main()
