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

`/harness-review` reviews current-project changes and adds a whole-repository Fresh pass when no new
findings appear. PR URLs delegate to `pr-review`.
`/hn-review` is conversational shorthand for the same topic and subcommands, not a separate skill or folder.

Action matching applies only to the explicit action token: exact canonical actions and documented
aliases take precedence; otherwise exactly 3 or 4 leading letters may select one canonical action
in this topic. Multiple matches: show choices and ask; no match: show help. Ambiguous or unknown
tokens execute nothing. Do not prefix-match aliases, skill names, targets, paths, options, or other
arguments. Case handling, natural-language routing, full names in menus and registrations, the
read-only bare default, and each procedure's arguments, permissions, and confirmations stay
unchanged; abbreviation adds no confirmation. This is conversational routing, not script argument parsing.

- Bare invocation, `list`, `status`, and `help` show review results and actions without launching a
  reviewer. `run`, explicit scope/options, or a PR URL follows the
  [review procedure](./references/workflow.md). Unknown actions show help.
- Apply `/rules apply` and project instructions, then the `harness` runtime's Script Permissions and
  Agent Fallback, Runner Inheritance, and Reuse or New procedures.
- The coordinator repeats Changes -> Full until no supported unfixed issues remain: findings go
  through the existing dev/proposal workflow, and review resumes after fixes without a new request.
  Only a stable clean round with no outstanding issues completes the request; unavailable fixes,
  access, or validation leave it pending or blocked.
- Keep snapshots, read-only permissions, and up to two passes per snapshot. Inadequate coverage is
  blocked, not clean. Local edits restart review up to twice; continued edits return `Partial`.
- Security guidance joins the same passes, not an extra pass. Existing budgets, limits, and
  pause/stop requests apply; no permissions are added. Do not add a fixer or busy-loop on unchanged code.
- Use `/grilling` in the attended coordinator only for a consequential design or risk choice;
  workers never launch interviews, and grilling never replaces independent review.