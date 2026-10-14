---
name: harness-decide
description: "[closed|all] Alone: open decisions. Text: explain it, then decide. Keep the harness decision register: list open decisions apart from optional setup, explain a decision or question with its options, and save the choice, or leave a new question open. Shorthand: /hn-decide. Overlaps with architecture-decision-records on history; owns the compact bulletin and register."
metadata:
  author: wzlwit
  version: "4.0.0"
argument-hint: "[closed|all] [<question or ID>]"
---

# Harness Decide

`/harness-decide` owns the compact decision bulletin and register; full rationale belongs in ADRs.
`/hn-decide` is chat shorthand for the same topic, not a separate skill or folder.

Menu words are the actions in brackets. A first word that is a menu word, or exactly 3 or 4 leading letters
of one, selects that action when the rest of the request fits it; otherwise ask. Several matches show choices
and run nothing. Anything else is text, and no input at all is the skill alone. Matching never applies to
skill names, targets, paths, or other arguments, and never changes an action's arguments, permissions, or
confirmations. This is conversational routing, not script argument parsing.

| Input | What happens |
| --- | --- |
| Alone | Show open decisions and a one-line **Configuration When Needed** summary, then offer to go through them one at a time ([bulletin](./references/workflow.md#bulletin-display)) |
| Text | Explain a decision ID, question, or statement, then ask for the choice ([explanation procedure](./references/workflow.md#explain-a-decision-or-question), [answer step](./references/workflow.md#ask-for-and-save-the-choice)) |
| `closed [<count>]` | Show the five most recently decided items, or the number given ([views](./references/workflow.md#no-arguments-read-only)) |
| `all [<count>]` | Show open and recently decided items, then the detailed setup checklist ([views](./references/workflow.md#no-arguments-read-only)) |

- Alone (`-Action Show -Filter Open`) shows explicitly recorded Open/Proposed decisions and the
  current human choices, plus a one-line **Configuration When Needed** summary and source link when
  optional setup is documented. It then offers once to go through the open decisions one at a time,
  explaining each and asking for its choice; no answer saves nothing. The view ends with one line
  naming the text uses: give a decision ID, question, or statement to explain and decide it, or an ID
  with a choice to save it at once.
- Text follows the [explanation procedure](./references/workflow.md#explain-a-decision-or-question):
  a plain-language answer with an options table, evidence-backed reasons, a worked example, the
  trade-off, and the status. Then it asks for the choice, and the choices include **Leave it open**.
  For a decided ID, it explains what was decided and why and asks whether to keep it; a new choice
  supersedes it. The answer is saved with the person who answered as owner (`-Action Record` with
  `-Id <id>` or `-Question <question>`, `-Choice <choice>`, and `-Owner <owner>`). **Leave it open**
  saves a new question as Open (`-Action Record -Question <question>`, with an optional
  `-Recommendation` and no `-Choice`) and saves nothing for a decision already recorded. No answer
  saves nothing. An ID with a choice, such as "D-004 B, because it is simpler", is saved at once.
- `closed` maps to `-Action Show -Filter Closed` and `all` to `-Action Show -Filter All`; a number
  maps to `-RecentCount`, from 1 to 100. Showing saves or accepts nothing.
- Keep explicitly recorded Open/Proposed decisions visible; never hide or reclassify them as optional
  configuration. Missing configuration is an open decision only when requested or enabled work needs
  a human choice that saved settings, inheritance, or defaults cannot resolve.
- Before showing, explaining, or saving, read the [decision procedure](./references/workflow.md) for
  the helper, the display rules, and the register.
- Apply `/rules apply` and project instructions. A grilling proposal is not an accepted decision;
  consequential rationale may use ADRs as authorized.