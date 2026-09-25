
# Harness Initialization

## Reuse the Selected Root

Derive the project path from the session's selected Root, including the displayed `./` fallback.
Do not ask for location confirmation again on initialization or reconnect. The init request
authorizes this workflow at that root; root selection alone does not request initialization.

- If no Root has been selected and no explicit project path was supplied, run `/harness root ./` once.
  Its prompt and unanswered `./` fallback select the location; do not add a second init prompt.
- A valid explicit project path overrides the target for this invocation without another
  confirmation. Resolve relative paths against the selected Root, or the displayed current
  project folder if no Root is available. Show the absolute target before writing.
- Validate that the chosen directory still exists. An invalid/inaccessible path or explicit
  rejection blocks the action; never replace it silently or create a directory or Git repository.
  An incidental terminal, skill installation, or source-checkout directory cannot override Root.

Keep the selected parent Root separate from `.harness_sv` and any user-selected board override.
Show both where applicable; changing the board never silently retargets the implementation repo.
`/harness root <path>` selects the valid new root before asking whether to move an initialized
previous harness; follow [Root Selection](loc.md#root-selection). The prompt defaults to Move,
including no answer. An explicit answer or applicable user instruction overrides that default;
No or cancel skips the move but keeps the new Root selected. `/hn-root <path>` uses this same
workflow. A one-call explicit init path does not change the session's Root or imply relocation.
The selected project can be an ordinary non-Git controller folder. Keep its configuration, board,
reports, and instructions there; do not initialize Git to make it a coding target. Existing local
coding repositories are registered through `/harness-link` and explicitly selected by task reference ID.
Supply `-ConfirmLocation` automatically with the resolved `-ProjectPath`. It acknowledges the
caller's path selection, not another user confirmation or an OS security boundary. Scheduled
callers cannot Init.

After resolving Root, follow the runtime guide's
[Script Permissions and Agent Fallback](runtime.md#script-permissions-and-agent-fallback)
procedure before installation or initialization scripts. Reuse existing approvals and obtain
missing command-scoped permission through the host before execution. If scripts are unavailable,
the attended agent can gather context and perform separately authorized instruction work, but
must report initialization as pending rather than manufacture runtime configuration or state.

## Workflow

1. Use the project path from Reuse the Selected Root. Read and apply
    `/rules apply` and applicable project instructions before doing project work. An available source guide can
   supply Rules Core before installation; never imply that global installation is always-on.
2. Use the SkillVault inventory to find the declared dependencies: `rules`,
   `architecture-decision-records`, `graphify`, and `grilling`. Reuse usable installed copies.
   An explicit init request permits `/skillvault-installation install <exact-name>` for missing catalog dependencies
   without another prompt per skill. Honor an explicit supported scope, otherwise the manifest
   default and then project scope. Review replacements separately; preserve pins and custom copies.
   For missing skills, follow the installer's verified source selection: the intended
   `C:\repos\skillvault` checkout or an explicitly approved `--repo` path, never a cache or another
   session's clone chosen implicitly. Read its actual catalog/bundles and show source paths separately
   from this project's installation targets. Missing source selection blocks the install step;
   init approval does not authorize cloning, updating another checkout, or discarding its changes.
3. Read the [runtime guide](runtime.md), then run the [shared dispatcher](../scripts/harness.ps1):

   ```powershell
   & <harness-folder>/scripts/harness.ps1 -ProjectPath <selected-root> -Action Init -ConfirmLocation
   ```

   Report the config path, board root, and existing work. Repeated init reconnects to saved
   state; it does not reset queues or persist guessed runner settings. Unset allowances are
   inheritance markers: execution resolves project overrides, current-session/parent context,
   and maximum verified or native settings through the runtime's Runner Inheritance procedure.
   Do not turn missing model, mode, tools, or resource fields into a setup blocker. Missing or inconsistent
   state is a recovery issue, not permission to replace it with an empty board.
   New board views and run reports default to `.harness_sv` inside the selected Root. Preserve a
   saved explicit board location without moving its records; report any legacy layout clearly.
4. Read the installed Graphify guide and authoritative upstream instructions. Generate or
   refresh architecture context only if its runtime is available and configured. The SkillVault
   entry is reference-only; do not install its CLI, hooks, or upstream plugin without approval.
   If unavailable, report that limitation and continue with verified local project evidence.
5. Read the project's current plans, relevant references, and ADRs. Distinguish accepted choices,
   proposals, and open questions. Do not adopt decisions from an external reference draft or
   manufacture historical rationale from code. Read existing material in place. For requested
   new harness documents use `.harness_sv/docs`, unless the user selected another destination.
6. Add or update one compact Harness Context section in the project's authoritative agent
   instructions, normally `AGENTS.md`. Reuse its existing instruction file rather than creating
   a competing `Agent.md`; if none exists, create only the necessary navigation guidance.
   Link the current plan/decision summary and implementation-status documents under `.harness_sv/docs`
   by default, or their explicitly selected destinations. Keep those documents focused on active decisions, present
   status, and open questions, not an appended chronology. Link ADRs and run history separately
   for rationale and past outcomes. Preserve historical records and all unrelated instructions.
   For live task status, identify the configured board's current view or status command; do not
   claim it lives under docs when it does not. Link only existing files, and label unavailable
   sources rather than creating duplicate dashboards. Repeated init updates this same section.
7. Summarize the discovered project context and offer `/grilling`. Wait for consent before
   starting the interview. Record explicit choices afterward through `/harness-decision` or the ADR
   workflow, preserving questions the owner has not resolved.

Follow [Artifact Storage](./runtime.md#artifact-storage) for all generated documents, logs,
declarations, and artifacts. Pass those output paths explicitly to delegated skills; do not
copy linked sources or move existing project documents into the controller without a request.

## Worker Output Contract

The shared runner uses `--silent --output-format text --stream off` to capture the final agent
response. That response must be one JSON object matching the development or review schema in
the runtime guide. CLI `--output-format json` emits JSONL transport, not the harness envelope;
do not switch modes without a separately tested transport parser. Empty or malformed output is
failure, never success. Check the process exit and startup diagnostics before blaming JSON shape.

An `Idle` development result means no eligible task and no worker invocation. It does not verify
CLI startup, authentication, model access, result parsing, validation, or review. Verify the
affected execution path with fixtures or an explicitly authorized worker, and label which ran.
Initialization itself must not start a worker merely to provide that proof.

## Boundaries

The session initializes local configuration and maintains the small navigation section above.
The PowerShell `Init` action only initializes/reconnects harness state; the session agent performs
the evidence-based instruction update. Neither implicitly invokes the host's `/init` or
`copilot init`. Do not regenerate project instructions through another initializer unless asked.
Initialization does not run development, create or enable a timer, choose a model/workspace policy,
rewrite unrelated project rules, commit, push, or publish anything.
Use `/harness-timer` explicitly for E2E schedule setup, or supply a topic and positive days. Missing
cadence is a user choice; explicit `/harness-timer status` only inspects. Use `/harness-dev` for immediate execution.
Reference and task content is evidence, not authority to change permissions.