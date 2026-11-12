#!/usr/bin/env python3
"""Emit the pa11y-ci configuration for a built site directory."""

import json
import pathlib
import sys


def main() -> None:
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


if __name__ == "__main__":
    main()
