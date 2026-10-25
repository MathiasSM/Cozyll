---
title: "Formatting"
date: 2024-01-10
published: 2024-01-11
lastModifiedAt: 2024-02-15
description: "Headings, emphasis, links, quotes, code, and footnotes."
path: /prose/formatting
aliases: [/old-formatting]
---

This post demonstrates the core prose constructs: headings, emphasis, links, quotes, code, and footnotes.

## Headings

Headings start at level two here, because the page template already renders the title as the single level-one heading. A section can nest further.

### A subsection

Subsections descend one level at a time.

#### A sub-subsection

And keep descending, with no skipped levels.

##### A fifth-level heading

Still descending.

###### A sixth-level heading

The deepest level.

## Paragraphs and line breaks

A paragraph is a run of text. A line break is forced with two trailing spaces.  
Like this one.

## Emphasis

Text can be *emphasized*, **strong**, ~~deleted~~, or shown as `inline code`.

## Links

Links can point [to a page](/prose/), [to a section](#emphasis), [to an external site](https://example.com), or [to an email](mailto:example@example.com).

## Blockquotes

> A blockquote contains quoted text.
>
> > It can nest another level.
>
> And return to the first level.

## Code

An indented code block:

    def greet(name):
        return "Hello, " + name

A fenced block with a language:

```python
def greet(name):
    return "Hello, " + name
```

## A horizontal rule

A rule separates sections.

---

## Notes

A sentence with an inline footnote.^[An inline footnote stays near its marker.] And one with a reference footnote.[^1]

[^1]: A reference footnote defined at the end of the document.
