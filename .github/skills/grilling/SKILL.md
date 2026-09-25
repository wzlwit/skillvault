---
name: grilling
description: Stress-test a plan, decision, or idea through a staged decision-tree interview. Overlaps with architecture-decision-records on trade-offs and planning-with-files on planning; focuses on reaching a shared decision.
metadata:
  author: null
  maintainer: wzlwit
  version: null
---

# Grilling

Interview the user until the plan has a shared understanding. Map it as a design tree:
each decision branches into the decisions that depend on it.

Work in rounds. The frontier is every decision whose prerequisites are settled: questions
that can be asked now without guessing at answers. Ask the whole frontier in one round,
number each question, give a recommended answer, then wait for the user's answers before
the next round.

Format each round as:

```text
Q1 - Question title: Question body, including choices when useful.

Recommended answer: ...

---

Q2 - Question title: Question body, including choices when useful.

Recommended answer: ...
```

Each answer reshapes the tree. Recompute the frontier after every round. A question whose
answer depends on another open question belongs to a later round, not the current one.

Find environmental facts yourself using available tools; do not ask the user for facts that
can be checked. The user owns decisions. Finish when the frontier is empty and do not act
on the plan until the user confirms shared understanding.

## Supporting Research

For supporting research, inspect an explicit source first; otherwise use local evidence,
configured accessible internal sources, then authoritative external sources only as needed.
Keep private details out of public searches. This order never expands working permissions,
replaces an unavailable explicit target, or overrides a stricter source-specific procedure.
