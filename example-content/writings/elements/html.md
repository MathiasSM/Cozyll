---
title: "HTML"
date: 2024-06-01
description: "Raw HTML, definition lists, fenced divs, and inline elements."
path: /elements/html
---

This post demonstrates raw HTML and richer block constructs.

## Definition lists

Term
:   A definition list entry.

## Fenced divs

::: {.example-note}
This paragraph sits inside a `{.example-note}` div, styled by the example stylesheet.
:::

## Raw HTML

A raw HTML block passes through:

```{=html}
<details>
  <summary>Click to expand</summary>
  <p>This is raw HTML, inserted verbatim.</p>
</details>
```

## Inline HTML

Inline elements: <kbd>Ctrl</kbd> for a key, <mark>marked</mark> text, a variable <var>x</var>, sample output <samp>OK</samp>, an <ins>insertion</ins>, a <del>deletion</del>, and a date: <time datetime="2024-06-01">June 2024</time>.

A <dfn>defined term</dfn>, an <abbr title="HyperText Markup Language">HTML</abbr> abbreviation, a <cite>cited work</cite>, an inline <q>quotation</q>, and an <address>example@example.com</address> address.

## Raw HTML inside markdown

A blockquote containing a raw inline element:

> A quoted line with a <mark>highlighted</mark> word.

A list with an inline element:

- An item with a <kbd>key</kbd> inside.
