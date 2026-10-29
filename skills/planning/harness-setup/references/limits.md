
# Harness Restrictions

Contents: Inspect; Declare; Supported Fields; Situations and Responses; Limits and Handoff.

Define machine-checked boundaries in the existing harness configuration. `/rules` manages
human-readable working guidance; it does not substitute for these runtime checks.

**Listing only inspects; it never configures.** Installing the skill, `policy list limits`, or a
request without a declaration does not add example policies, select limits, edit an AI-rules
document, initialize the project, or start workers. Situations below are usage guidance, not implicitly accepted rules.

## Inspect

1. Resolve the project and apply `/rules apply` and applicable project instructions. Locate the
   installed `harness-runtime` dependency and read its `references/runtime.md` before changing policy.
  Follow its Script Permissions and Agent Fallback procedure before any helper script. Reuse
  existing tool approvals or request missing command-scoped permission through the host. This
  does not grant new `allowedTools`, models, paths, or budgets in the harness policy. An attended
  agent may inspect accessible policy files without scripts, but must keep inspection read-only
  and use the declaration/apply workflow for any persistent policy change.
2. For `policy list limits`, run its shared `scripts/harness.ps1 -ProjectPath <root> -Action Restrict`. Report the declared
   restrictions, configured runner permissions/model, effective numeric caps, and active pauses.
   Also list the review models from its `reviewPanel`: each family's models, which ones
   `allowedModels` permits, the reviewers the next Changes pass will try, and `fullPass`, the models
   the Full pass starts with when it's on.
   Uninitialized projects are reported without creating state; creating the harness is a separate request.
3. Follow the runtime's Runner Inheritance procedure: missing allowances use current-session or
  parent settings, then maximum verified/native capability. Pass `-RunnerContext` or
  `-RunnerContextPath` when invoking the helper; it shows effective values without persisting them.
  Do not demand duplicate configuration or add restrictions merely because fields are absent.
  Explicit denials and incompatible supplied values still matter; unknown grants are not invented.

## Declare

`/harness-setup policy set limits <file>` reads the JSON declaration and asks once before saving it.
For a prose request, inspect the actual runner/test configuration, clarify the intended boundaries,
and author the requested declaration at an explicit project path. Do not choose live thresholds
from this guide or copy permissions from task descriptions.

```powershell
& <harness-folder>/scripts/harness.ps1 -ProjectPath <root> -Action Restrict -PolicyAction Declare -DefinitionPath <file>
```

Show the full current/proposed policy, removals, and affected commands, then ask once, as Ask Once in
the runtime guide describes. On a yes, rerun with `-Apply -Actor <human-owner> -Reason <reason>`; a
request that already says to save is the yes. Without an answer nothing is saved, because limits
are permission boundaries. Obtain a missing owner or reason rather than inventing one, and save
exactly the file shown.

The declaration **replaces only** `config/policy.json`'s `restrictions` object in layout 2; it does not merge
omitted fields. Omission removes that additional restriction, and `{}` explicitly clears the
declared restrictions, so review removals carefully. Runner settings, test definitions, fallback
policy, and safety pauses remain unchanged. Policy changes require an idle runner and no unresolved
active-run marker. Applying policy launches no work and changes no schedule.
Direct edits use that same authoritative file without an import step. Legacy controllers retain
their flat config until their layout is converted. Missing/invalid declarations block new operations;
pause/stop remains available and changes no declaration.

## Supported Fields

No default restriction is added. All fields are optional: omission, JSON `null`, blank strings,
empty lists, `None`, and `Max` add no local restriction. Inherit the current session/parent, then
use maximum verified/native availability. Placeholder-only lists behave the same way. Prefer
omission or `null` (`None`); approved declarations normalize placeholders to `null` when saved.
Concrete parent restrictions remain in force. Nonempty allowlists match exact values, not wildcards.
CLI permission patterns are compared as strings here and interpreted by the CLI when used.
Do not use an empty list as a deny-all control; use an explicit safety pause to stop execution.
Do not fill `allowedModels` from an editor screenshot: it is an allowlist, and available runtime models
may differ. The review models come from the bundled default list described in the runtime's Review
Panel, which skips models the CLI rejects; `allowedModels` only narrows that list.

| Field | Enforced boundary |
| --- | --- |
| `allowedModels` | Explicit model names allowed for every agent session; narrows the review model list but does not select a model |
| `allowedTools` | Permitted `runner.allowedTools` permission strings; never adds an approval |
| `availableTools` | Allowed exposed tool names, including the review tools `view`, `glob`, `grep` |
| `deniedTools` | Additional CLI `--deny-tool` patterns; existing read-only review denials remain |
| `workspaceModes` | Allowed development modes, `current` or `worktree`, including saved task workspaces |
| `workingRoots` | Allowed normalized launch directories and descendants; relative roots resolve against the project |
| `testEnvironments` | Permitted environment labels for manual/scheduled/post-dev test flows and named monitor checks |
| `allowedExecutables` | Direct worker/test/validation launchers, resolved by `Get-Command`; not their subcommands |
| `maxProcessMinutes` | Positive time ceiling per process and for the shared test-flow/validation budget |
| `maxAgentCredits` | Positive CLI credit ceiling per agent session, not aggregate task spend; the Copilot CLI refuses caps below 30 |
| `maxTasksPerCycle` | Positive integer ceiling on tasks/checkpoint handoffs per invocation |
| `maxParallelReviewers` | Positive integer ceiling on review-panel reviewers running at once in one pass; `1` runs them one after the other |

Numeric caps, when supplied, use the stricter of the inherited and project ceilings. Omitted
caps use existing host/native allowances without an invented number. The runner serializes development, independent review, and tests
with one shared lock, so only one run is active per controller; that concurrency is fixed at one, not
configurable to a larger value. Inside one review pass, the two panel reviewers run at the same time
on the same pinned snapshot unless `maxParallelReviewers` is 1.

An explicit no-additional-restriction declaration can use the following markers. Nothing is
installed or granted automatically, and inherited limits still apply:

```json
{
  "allowedModels": "None",
  "allowedTools": "None",
  "availableTools": "None",
  "workspaceModes": "None",
  "workingRoots": "None",
  "maxProcessMinutes": "Max",
  "maxAgentCredits": "Max",
  "maxTasksPerCycle": "Max",
  "maxParallelReviewers": "Max"
}
```

## Situations and Responses

| Situation | Response |
| --- | --- |
| Inspect before enabling automation | `/harness-setup policy list limits`; report current settings without writing |
| Limit tests to a reviewed environment | Declare `testEnvironments`; scheduling still needs that environment's separate approval |
| Run panel reviewers one after the other | Declare `maxParallelReviewers: 1`; each pass takes longer, and project timers size their limits for it |
| Require isolated development workspaces | Declare `workspaceModes`; old saved current-checkout tasks are also checked |
| Narrow tools, commands, or launch directories | Review matching fields and actual runner configuration; declare explicitly |
| A runtime preflight violates a declared restriction | Deny launch, retain evidence, and persist a project stop/pause through `/harness-setup policy` |
| Change a limit after a failure | Declare the approved replacement; this does not resume a paused target |

## Limits and Handoff

These checks are not an OS sandbox. `workingRoots` checks normalized directory paths, not every
file access or symlink target. A permitted shell/interpreter can invoke other commands or access
other paths; scope CLI permissions and use host/account isolation for hard filesystem, network,
credential, and process boundaries. Same-user workers can potentially tamper with controller files.
Do not claim this policy is tamper-proof, protects secrets, or enforces arbitrary natural-language rules.

Credit ceilings are the CLI's per-session control, not a billing guarantee or total task/daily cap.
Without a declared ceiling no cap is passed, so only account limits apply. The CLI's smallest cap is
30 AI credits; a smaller declared or split cap blocks the run with that reason instead of counting as
a worker failure.
Named monitor checks use `pwsh` to read a local snapshot under process/directory/environment limits,
without an AI session; the source file's parent directory is also checked against `workingRoots`.
Development and review are separate sessions. The adapter does not parse reliable credit-usage or
individual denied-tool events from the worker's text result. Report that limitation rather than
claiming every remote/CLI violation is detected. Standalone review reads the project checkout;
use `workingRoots` to constrain its launch location too.

Use `/harness-setup policy set fallback <file>` for failure thresholds and `policy pause|stop|resume`
for explicit target controls. Applying or clearing a
restriction never clears a safety pause, retries work, discards edits, or widens fallback permissions.