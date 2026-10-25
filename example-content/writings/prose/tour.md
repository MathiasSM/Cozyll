---
title: "A tour of the example content"
date: 2024-02-20
description: "A longer post that mixes prose, tables, code, and footnotes."
path: /prose/tour
---

This post is a longer, flowing piece of prose. It exists because most of the other posts in the example content are short demonstrations that jump straight from one construct to the next, while real writing is mostly paragraphs.

## Why longer text matters

A real post is not a list of features. It is a sequence of paragraphs, each building on the last, with the occasional heading to give the reader a place to rest and a way to find their place again. Short posts do not exercise the styles that make longer text comfortable to read: the space between paragraphs, the measure of a line, and the way a heading clears the text around it.

So this post stretches those styles. It also, as a matter of course, mixes in several of the constructs the example content demonstrates elsewhere, so they can be seen working together rather than in isolation.

## The example content at a glance

The example content is organized into a handful of groups, each focused on one area of the generator's input:

| Group     | Focus                                    |
| --------- | ---------------------------------------- |
| prose     | Core Markdown text, lists, and footnotes |
| tables    | The four Pandoc table syntaxes           |
| code      | Syntax highlighting and math             |
| languages | Language front matter, CJK, and ruby     |
| elements  | Raw HTML, forms, and controls            |

## A note on footnotes

Footnotes keep an aside out of the flow of a sentence.^[Like this one, which is an inline footnote. It stays near its marker, and a back-link returns the reader to where they left off.] They are useful in longer writing, where a sentence needs a caveat that would otherwise interrupt the argument.

## Code in prose

Longer writing also leaves room for a short code block without it feeling forced:

```haskell
main :: IO ()
main = putStrLn "An example"
```

And a quote, for good measure:

> A paragraph is not a luxury; it is the basic unit of argument.

## Where to go next

From here, the other groups show the remaining features in detail: the [languages](/languages/) posts for ruby and CJK, the [tables](/tables/) posts for table syntax, and the [elements](/elements/) posts for raw HTML and controls.
