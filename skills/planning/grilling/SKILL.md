---
name: grilling
description: Stress-test a plan, decision, or idea through a staged decision-tree interview. Overlaps with architecture-decision-records on trade-offs and planning-with-files on planning; focuses on reaching a shared decision.
metadata:
  author: Matt Pocock
  maintainer: wzlwit
  version: null
---

# Grilling

Adapted from Matt Pocock's grilling skill (`https://github.com/mattpocock/skills`,
`skills/productivity/grilling`), MIT; see `UPSTREAM-LICENSE`. Follow the original below with
these SkillVault changes; where they differ, these changes win:

1. Look up environmental facts with the available tools, through a sub-agent when the host
   provides one. Never ask the user for facts that can be checked.
2. For supporting research, inspect an explicit source first; otherwise use local evidence,
   configured accessible internal sources, then authoritative external sources only as needed.
   Keep private details out of public searches. This order never expands working permissions,
   replaces an unavailable explicit target, or overrides a stricter source-specific procedure.

## Original

<!-- upstream:begin -->
<!-- Original: https://github.com/mattpocock/skills skills/productivity/grilling at d81f3a183412e71a5b1e84ca21bc1a35eea03a60. Refresh replaces this section; put SkillVault changes outside it. -->

Interview the user relentlessly until you reach a shared understanding. Map this as a **design tree**: every decision branches into the decisions that hang off it.

Work the tree in **rounds**. The **frontier** is every decision whose prerequisites are already settled: the questions you can ask _now_ without guessing at answers you haven't heard yet. Ask the whole frontier in one round: number each question and give your recommended answer. Then wait for the user's answers before the next round.

Format a round like so:

```
❓ **Q1** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>

---

❓ **Q2** - **<question title>**: <question body, might be multiple paragraphs, including multiple choices>

➡️ <your recommended answer>
```

Each round the user answers reshapes the tree: settled decisions push the frontier outward and unblock questions that depended on them. Recompute the frontier and ask the next round. A question whose answer depends on another question still open in this round belongs to a _later_ round, not this one.

Finding _facts_ is your job, never the user's. When a frontier question needs a fact from the environment (filesystem, tools, etc.), dispatch a sub-agent to find it; don't ask the user for anything you could look up yourself. Don't block on it: a running exploration is an unsettled prerequisite, so only the questions downstream of it wait for the sub-agent to report; ask the rest of the frontier now. The _decisions_ are the user's: put each to them and wait.

The session is done when the frontier is empty: every branch of the design tree visited, nothing left silently assumed. Do not act on it until the user confirms you have reached a shared understanding.
<!-- upstream:end -->
