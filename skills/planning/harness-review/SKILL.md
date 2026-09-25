---
name: harness-review
description: "Review current-project changes with a whole-repository Fresh pass when no new findings appear, automatically restarting when local files change. Use /harness-review or /hn-review
  with list, run, or explicit review options. Overlaps with pr-review on
  general review and differential-review on security; PR URLs delegate to
  pr-review."
metadata:
  author: wzlwit
  version: "1.0.0"
argument-hint: "[list|run] [<arguments>...]"
---

# Harness Review

The registered command is `/harness-review`. `/hn-review` is conversational
shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token. Exact canonical actions and documented
aliases take precedence. Otherwise, accept exactly 3 or 4 leading letters only when they match one
canonical action in this topic. Multiple matches: show choices and ask; no match: show help.
Ambiguous or unknown tokens execute nothing. Do not prefix-match aliases, skill names, targets,
paths, options, or other arguments. Preserve existing case handling and natural-language routing.
Use the resolved action's existing procedure with arguments, permissions, and confirmations unchanged;
no extra confirmation is required merely for abbreviation. Keep full names in menus and registrations
and preserve the read-only bare default. This is conversational routing, not script argument parsing.

No arguments or `list` shows existing review results and available actions; `status` and `help` are aliases.
It does not launch a reviewer, including through `/hn-review`. `run`, explicit scope/options,
or a PR URL selects the [review procedure](./references/workflow.md). Unknown actions show help.

Apply `/rules apply` and project instructions. Follow Script Permissions and Agent Fallback,
Runner Inheritance, and Reuse or New from the `harness` runtime. Keep snapshots, read-only
permissions, and up to two passes per snapshot. The coordinator repeats Changes -> Full until
no supported unfixed issues remain: publish findings through the existing dev/proposal workflow,
let dev fix and validate, then resume from Changes without another user run request. A findings
checkpoint releases the script's run lock; it does not complete the review workflow. Do not add
a fixer or busy-loop on unchanged code. Recheck earlier unresolved issues, including Full findings
outside the diff. No new findings triggers Full; only a stable clean round with no outstanding
issues completes the request. Unavailable fixes/access/validation leave it pending or blocked.

Review starts with the requested changes; Fresh covers the whole selected repository.
Inadequate coverage is blocked, not clean. Local changes restart the review on the updated
snapshot, up to twice; superseded findings stay in the report, not the current verdict. Continuous
edits beyond that round's bound return `Partial`, not completion. Fix-driven continuation rounds
have no fixed count but retain explicit budgets and pause/stop requests.
Worker errors and pinned PR snapshot changes do not retry.
Security guidance joins the same passes, not an additional security-only pass. Existing per-session
limits and outer budgets remain in force; no new permissions or settings are granted.

Use `/grilling` in the attended coordinator only when a supported finding needs a consequential
human design or risk choice. Routine defects remain review findings; a worker does not launch
an interview. Never use grilling to replace independent review or silently change standing rules.