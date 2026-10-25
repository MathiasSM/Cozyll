---
title: "Smart typography"
date: 2024-02-01
description: "Smart quotes, dashes, ellipses, and escaping."
path: /prose/smart-typography
---

Pandoc rewrites punctuation as it parses.

## What gets rewritten

"Double quotes" and 'single quotes' become curly, two hyphens -- become an en dash, three --- become an em dash, and trailing dots... become an ellipsis.

## Escaping

A backslash keeps characters literal: \-- stays two hyphens, \... stays three dots. Code spans are never rewritten: `--flag`.

## Subscript and superscript

Water is H~2~O and a square is x^2^. This is separate from math, which uses `$...$`.
