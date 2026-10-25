---
title: "Multiline tables"
date: 2024-03-04
description: "Multiline tables and a deliberately too-wide table."
path: /tables/multiline
---

A multiline table needs a full separator line at the top:

---------- ----------
Left       Right
---------- ----------
alpha      beta
gamma      delta
---------- ----------

## A too-wide table

A table with a very long, unbroken cell overflows its column. The example stylesheet wraps it in a scrollable `.wide` container.

:::{.wide}

| Key   | Value |
| ----- | ----- |
| short | short |
| a-long-unbroken-token | this-cell-contains-an-extremely-long-unbroken-string-that-forces-the-table-wider-than-the-page-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa |

:::
