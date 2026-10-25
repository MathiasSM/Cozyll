---
title: "Checkboxes"
date: 2024-06-03
description: "Task-list checkboxes are read-only by default."
path: /elements/checkboxes
---

Task-list checkboxes render read-only, since a static page can't persist their state.

## Read-only by default

- [ ] An unchecked item
- [x] A checked item

## Opt in to interactive

Wrap a task list in an `interactive` div to keep its checkboxes editable:

::: {.interactive}
- [ ] Toggle me
- [x] Me too
:::
