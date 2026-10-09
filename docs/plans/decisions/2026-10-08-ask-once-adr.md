# ADR: Ask Once for Harness Changes

- Date: 2026-10-08
- Status: Accepted. The owner designed the pattern for `/hn-monitor declare` and asked to check it
  and apply it to the other commands where it fits. The owner then reviewed the split in a grilling
  round on 2026-10-08 and confirmed the recommended answers, recorded below.
- Decision owner: Zhaolong Wang
- Scope: How harness topic commands that change saved state ask for approval.

## Context

Several harness commands used two steps: the command previewed, and the same command with `--apply`
saved. The owner found that verbose for monitor declarations and asked for one command that asks to
save, saves after a few minutes without an answer unless held, and then offers a timer that starts
only on a yes. Other commands differ in what an unanswered change could do: some only update a
declaration or record, while others start unattended work, change permission limits, clear a safety
pause, or move or delete data. A command that already names exactly what to change, such as
`/hn-timer disable <id>`, gains nothing from a question.

## Decision

1. **One request, one question.** A topic command that changes saved state shows the change and asks
   once (**Save now** or **Hold**). `--apply` or a request that already says save is the answer;
   `--hold` keeps everything unchanged until the owner says save. There is no separate preview command.
2. **Act at once when fully specified.** Monitor `accept <id>` and a timer `set` with its target and
   duration (no Reuse or New choice), `disable <id>`, or `resume <id>` apply without a question and
   report the result. Anything that had to be drafted, resolved, or chosen first asks once. `auto`
   always asks, because it starts automatic work on its own.
3. **Save after 1 minute** without an answer for monitor and test `declare`. They update a
   declaration and run nothing by themselves.
4. **Hold** without an answer for every other change: `auto`; a timer `set` that needed a choice,
   timer `disable` or `resume` with `--all`, and timer `clean` and `migrate`; `policy set`,
   `policy resume`, layout `migrate`, history `clean`, and board renames and exports. They start or
   stop scheduled or automatic work, change permission boundaries, clear a pause, or move, replace,
   or delete data.
5. **Offered follow-ups default to no, without waiting.** A timer offered after a monitor declaration
   is shown in the reply with its exact `/harness-timer set` command; it starts only on a yes, which
   may come later. Test declarations offer no timer, because flows run in the development loop or on
   demand.
6. **Pending declarations are visible.** The `/hn-monitor` and `/hn-work test` lists show
   `pendingDefinitions`: definition files that differ from the saved declarations. They include held
   drafts and also older files that later declarations passed, so the list says what differs rather
   than calling each one a draft.
7. **Existing exceptions stay.** An explicit `pause` or `stop` applies at once; Root's move prompt
   keeps its Move default (owner confirmed); an unanswered Reuse or New choice changes nothing. The
   runtime scripts keep their preview-without-`-Apply` behavior; this decision governs how the topics
   ask.

## Out of Scope

Commands outside the harness keep their own confirmation (owner confirmed), because they edit or
delete files elsewhere or write outside the machine: `/rules upsert` and `remove`,
`/skillvault-installation install`, `update`, and `uninstall`, `/skillvault-authoring remove`,
`/schedule-manager`, `/pr-publish`, and `/pr-review configure`. `/harness-decision record` records
only the owner's own answer.

## Consequences

- The topics need no `--apply` flag in their synopsis; old commands with `--apply` still work.
- `harness-monitor` 2.0.0, `harness-work` 2.0.0, `harness-project` 2.0.0, `harness-runtime` 3.0.0,
  and `harness-timer` 3.0.0 carry the change; the shared rule is the runtime guide's Ask Once section.
  The timer moves to a major version because a fully specified `set`, `disable`, or `resume` now
  applies instead of previewing. `harness-work` and `harness-runtime` take their major versions from
  the same release's [review levels](./2026-10-08-review-levels-adr.md).
- A held change leaves nothing behind except a drafted declaration file, which stays for later edits
  and appears in the list until it is saved or removed.
