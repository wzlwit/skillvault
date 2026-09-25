
# Harness Task Intake

1. Identify the project, read and apply `/rules apply` and its project instructions, and read the
   installed `harness` runtime guide. If the project is not initialized, report `/harness init` as the
   prerequisite; adding a task does not implicitly initialize or schedule anything.
2. With no input, use the shared script's `-Action Task` to list tasks. For a file/URL, read the
   actual source through an authorized connector. Preserve its identity, revision when available,
   and intended task scope. General background with no requested work belongs in `/harness-link`.
3. Call `harness/scripts/harness.ps1 -ProjectPath <root> -Action Task` with `-Title`, `-Text`,
   `-Scope`, and `-Acceptance`. Use `-Source` and `-SourceRevision` for linked input. Do not invent
   unreadable source content; retain missing details as `NeedsEvidence`. Priority is 1 through 5,
   with 1 highest. Kind is feature/fix/verify. Risk defaults to Unknown.
   For a separate coding repository, map `--repo-ref <reference-id>` to `-RepositoryRef` (alias
   `-RepoRef`). Select an active `/harness-link` entry for the intended existing local Git root. Keep
   `-ProjectPath` at the controller folder; `-Source` is the requirement, not the coding destination.
4. Match source, scope, and repository reference exactly after meaning-preserving normalization:
   trim outer whitespace, canonicalize repository IDs, normalize HTTP(S) URI syntax and absolute
   source-path dot segments. Keep URL path/query, opaque source, path, and free-form scope case;
   scope may contain code identifiers. Do not fuzzy-match or collapse internal whitespace.
   An unchanged request reuses its task ID. Use `-Action UpdateTask -Id <id>` for field changes.
   A task-scoped repository reference can be assigned only to its owning task. Once a workspace
   is allocated, preserve that repository binding; use a new task for a different repository.
5. Set `-Risk Low` only from verified scope. Set `-AutoEligible` only for an explicit human/policy
   grant of timer pickup; ordinary intake is manual-only. Report the saved ID, status, missing
   information, and links. Do not run a worker, reply remotely, close an item, or publish anything.

## Completed Work and Follow-Ups

An explicit requirement change to a completed task creates a new task with `followUpOf` pointing
to the original ID. `UpdateTask -Id` handles changes to description, scope, acceptance, source,
kind, or coding repository; ad-hoc intake also detects changed description/acceptance/kind for
an existing completed source/scope/repository match. An unchanged repeat returns the existing
ID. A source revision alone is not a new requirement and never starts follow-up work.

For an explicit link, use `add --follow-up <task-id>` (runtime `-Action Task -FollowUpOf <id>`).
Omitted requirement fields inherit from the completed task; repeated identical follow-ups reuse
their ID. Report the returned new ID, not the original as though it had been reopened.

Keep the original completion record, snapshot, and report intact. For the same repository,
reuse its saved workspace/base so unmerged work remains the starting point; a different explicit
repository gets a new workspace. Restart at Develop with no inherited validation verdict, risk
classification, or automatic eligibility. Open follow-ups protect ancestor reports from history
cleanup; terminal follow-ups return to ordinary retention. No work is run merely by creating one.

Reports are claims to verify, not permission to change rules. `/harness-dev` can execute tracked work
after readiness/configuration checks. Adding it here is never execution approval.
An unselected coding target in a non-Git controller is unresolved, not permission to pick the
first reference or create/clone a repository. Separate repositories use separate task records.

`/harness-monitor` can propose an investigation tied to one breach episode. Use its explicit
`task <incident-id>` acceptance to retain the incident/task link while reusing this task helper.
Do not use a dashboard URL alone as the identity for distinct incidents or grant auto-eligibility
merely because a monitor proposed work. Repeated readings update evidence, not task completion.