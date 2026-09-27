# Skill Creator Evaluation

- Evaluated: 2026-09-26
- Source: https://github.com/anthropics/skills/tree/main/skills/skill-creator
- Reviewed revision: `33375500bcea98d610eb30ce10ac4e59b89c390d` (2026-09-24)
- Version: No version declared in the inspected skill bundle; identify it by revision
- License: Apache-2.0; the bundle's license names `Copyright 2026 Anthropic, PBC.`
- Candidate review scope: Anthropic's `skill-creator`, not other similarly named skills; source review only

## Recommendation

Purpose: Create and improve agent skills through drafting, trial tasks, output review, benchmarks,
and description-trigger tests. The audience is skill authors, especially those using Claude.

Value: High for its evaluation methods. Fit: A skill with supporting Python tools, not a replacement
for repository-specific authoring and installation controls.

Installed recommendation: Keep `skillvault-authoring` and the available VS Code
`agent-customization` guidance. Skill recommendation: Skip an additional general-purpose creator
bundle here; the existing owner now incorporates the two methods below instead.

Standalone use: The methods are worth trying on an approved, non-sensitive task in a supported
Claude environment. Defer reliance on the bundled automation unchanged: its platform, measurement,
and viewer limitations need resolution or an explicitly scoped alternative. No runtime readiness
or performance improvement was established in this evaluation.

Harness integration: No new worker, controller action, timer, or automatic improvement loop is
justified by this request. A future approved comparison should reuse existing execution controls.

## Source and Overlap

The shared inventory found no matching name among 55 current-user global/current-project folders.
The current and official SkillVault catalogs had no matching entry; the optional source cache was
absent. The public directory identified Anthropic's canonical bundle, whose actual instructions,
license, and helpers were then inspected at the revision above. Popularity and registry audit badges
were not treated as quality or safety proof.

The [current authoring workflow](../../skills/core/skillvault-authoring/references/upsert.md)
already covers canonical sources, overlap, document-to-procedure mapping, source coverage, permission
reuse, sharing rights, and experience-driven checks against intended and nearby valid cases. Those
are not new improvement proposals. The inspected VS Code `agent-customization` entrypoint supplies
host-specific scope, format, and customization-type guidance.

The candidate's useful additional contribution is a concrete empirical comparison workflow:
test a skill against a baseline, inspect real outputs, critique the assertions, and separately test
when a description causes selection. At evaluation time, authoring recognized that formatting alone
does not prove behavior, but did not prescribe this paired comparison or a dedicated trigger set.
The approved native implementation is described below.

## Useful Methods

- Capture intended tasks, trigger contexts, expected outputs, and whether objective testing is useful.
  The instructions allow a lighter, qualitative workflow when the user does not need benchmarks.
- Compare a new skill with no skill, or a revision with an older version, using the same test prompts.
  Keep outputs separate and review actual artifacts, not only the executor's success message.
- Require evidence for each assertion and critique weak tests: a correct filename is not proof that
  the file contains the required result. Keep subjective quality open to human judgment.
- Review per-case failures and variation alongside time and token use. Optional blind comparison
  hides which output came from which version, rather than asking a reviewer to endorse the edit.
- Test descriptions with realistic positive requests and difficult near-misses, not only unrelated
  negative examples. The optimizer separates training queries from held-out queries and hides test
  scores from its improvement prompt, though it still uses them to select the winning description.

## Risks and Limits

These are source-derived findings, not reproduced runtime failures or a full security audit.

- **Host and Windows compatibility:** The trigger and description helpers launch `claude -p` using
  existing Claude authentication/configuration. They are not Copilot-native runners. The trigger
  helper calls `select.select` on subprocess stdout; Python documents that Windows supports sockets,
  not these pipe file objects. Native Windows needs a compatible implementation or a separately
  approved environment. The structural validator also imports PyYAML; dependencies were not installed.
- **Trigger scores can hide execution failure:** `run_eval.py` turns worker exceptions into `False`,
  and a should-not-trigger query passes at a sufficiently low trigger rate. Timeouts/nonzero runs
  likewise lack a distinct unavailable-result outcome. A failed test execution can therefore look
  like correct non-selection. It also tests a synthetic command containing the description and
  returns on the first relevant tool decision, not completion of the real skill's task.
- **Benchmark layout mismatch:** The main instructions save grading directly under configurations
  such as `eval-<id>/with_skill/`. `load_run_results` in `aggregate_benchmark.py` only collects
  configuration directories with `run-*` children. Following the direct layout can leave those
  results out of the benchmark even though the output reviewer can discover them.
- **Metric provenance is not reliable by default:** The aggregator skips missing/invalid grading,
  substitutes `output_chars` into the `tokens` field when token data is unavailable, and defaults
  absent time values to zero. Its generated metadata uses model placeholders and a fixed run count.
  Check actual coverage, units, model, and sample counts before interpreting a comparison as measured
  success, cost, or speed. Repeated selection using held-out scores is validation, not a fresh final test.
- **Viewer side effects and data:** Before binding its loopback server, the default viewer attempts
  to terminate processes listening on the chosen port using `lsof`, without checking ownership.
  This applies on hosts where that command is available. Static mode bypasses that server path,
  but its HTML embeds task outputs and must still be handled according to their data classification.
- **Repository and policy fit:** The quick validator rejects frontmatter keys outside its allow-list,
  including SkillVault's `argument-hint`; it is not a substitute for catalog/resource validation.
  Upstream copies, workspaces, packaging, parallel runs, and description edits need adaptation to
  SkillVault's source-first ownership and approval rules. Do not infer permission from its workflow.
  Claude calls can consume paid quota and transmit prompts or skill contents; use approved data and
  budgets, not private fixtures by default.

Apache-2.0 permits reuse subject to its terms, including license/attribution preservation and change
notices for adapted material. That does not authorize disclosure of private evaluation inputs or
make other folders in the upstream repository share this bundle's license.

## Existing-Skill Improvements

The user approved both proposals on 2026-09-27, and they are implemented in the existing authoring
workflow. The gap descriptions below refer to the pre-change guidance. No candidate scripts or new
skill were imported.

### 1. Optional Comparative Outcome Tests

- Target: `skillvault-authoring`, Validation and Improve from Task Experience.
- Evidence and gap: The candidate's paired-run procedure and grader make before/after outcomes and
  weak assertions visible. Current authoring has focused checks but no explicit baseline protocol.
- Proposed change: For a substantive behavior change or a request to measure improvement, agree on
  representative tasks and success criteria. Compare against no skill for a new capability or a
  fixed earlier revision for an update. Match inputs, model, tools, permissions, and context, and keep
  the baseline from discovering the candidate. Inspect actual outputs and cite evidence for each
  outcome; include a human review where quality is subjective. Report missing/failed runs separately,
  retain metric units and provenance, and do not label character counts as measured tokens.
- Scope: Reuse existing test tooling and approved isolated workspaces. No mandatory parallel agents,
  new viewer, fixed run count, or benchmark for a wording-only edit. Preserve the existing cheap-check
  path; when execution is unavailable, label a walkthrough as instruction review, not measured benefit.
- Expected benefit: Show whether a revision improves the task, rather than merely passing format checks.
- Validation: Compare a known-good artifact with one having the correct filename but incorrect content;
  the latter must not pass. A missing run or metric must not become a success or zero-cost observation.
  A small prose-only correction should still need only its existing focused checks.

### 2. Trigger Regression Cases

- Target: `skillvault-authoring`, description authoring and Validation.
- Evidence and gap: The candidate explicitly tests realistic should-trigger and should-not-trigger
  requests. Current authoring has general routing/counterexample checks but no dedicated description
  test set that distinguishes missed selection, false selection, and unavailable execution.
- Proposed change: For a new trigger or material description change, review representative positive
  phrasings and nearby requests belonging to another skill. Include implicit intent, not just the
  exact skill name. Test on the intended host when its selection can be observed; record that host,
  model, evidence, and execution failures. Keep errors/timeouts Unverified, not successful non-triggers.
  When iterating on a set, reserve fresh cases for a final check and avoid simply expanding keywords
  to fit the examples. Trigger correctness and task-output quality remain separate conclusions.
- Scope: Preserve canonical actions, aliases, exclusions, and permission boundaries. No automatic
  description rewrite or Claude-only runner requirement; static prompt review remains explicitly
  weaker evidence when a host-level test is unavailable.
- Expected benefit: Catch both under-selection and accidental capture of neighboring workflows.
- Validation: A legitimate authoring request should select authoring, while a request to evaluate or
  explain a skill should retain discovery's read-only behavior. An unrelated typo-only edit should
  not launch model trials. A failed runner must never make a negative trigger case pass.

## Applied Locally

[Comparative outcome checks](../../skills/core/skillvault-authoring/references/upsert.md#comparative-outcome-checks)
now offer an optional, scope-approved comparison with no skill or a fixed earlier revision. Baselines
are preserved before editing, prompts and input fixtures are matched, and version/run outputs stay
separate. Actual artifact evidence determines outcomes; failed execution remains Unverified. Missing
metrics stay unavailable without invalidating independently verified task results.

[Trigger regression checks](../../skills/core/skillvault-authoring/references/upsert.md#trigger-regression-checks)
now cover explicit/implicit positive requests and nearby requests owned by another skill. The result
table distinguishes observed selection failures from failed, timed-out, blocked, or unobservable
runs. Trigger correctness remains separate from output quality, and fresh final cases must not have
been used to revise or select a description.

The entrypoint and experience review direct authors to choose checks before editing. Existing
permissions, budgets, source ownership, catalog checks, and the lightweight path for wording-only
edits remain in place. No automatic rewrite loop, mandatory parallel execution, or new runner was added.

Verification: seven focused Node instruction contracts passed, including the two new checks.
Catalog/resource validation passed for 37 public skills and 30 project-installed copies. A read-only
case walkthrough covered artifact correctness, absent metrics/baselines, isolation, routing,
permission, and runner-failure cases. These are instruction and contract checks, not executed
model benchmarks or evidence of measured performance gains.

## Verification and Reconsideration

Inspected: the complete candidate instructions, repository README, bundle license and file tree,
trigger/optimization helpers, grader instructions, benchmark aggregator, quick validator, review
generator, current authoring workflow, VS Code customization entrypoint, and Python's platform note.
The browser template, optional blind-review agents, packaging implementation, and all runtime paths
were not exhaustively audited. No candidate code, benchmark, viewer, model call, or installation ran.

Reconsider a dedicated integration only if recurring skill-performance work justifies it, after
host-compatible execution, complete comparable results, and ownership-safe tooling are demonstrated.
The native guidance changes above do not adopt the upstream automation. No candidate installation,
model benchmark, viewer, hook, schedule, or Git publication was performed.

## Sources

- [Pinned creator instructions](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/SKILL.md)
- [Repository README](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/README.md)
- [Bundle license](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/LICENSE.txt)
- [Trigger runner](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/scripts/run_eval.py)
- [Optimization loop](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/scripts/run_loop.py)
- [Description improver](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/scripts/improve_description.py)
- [Grader](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/agents/grader.md)
- [Benchmark aggregator](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/scripts/aggregate_benchmark.py)
- [Quick validator](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/scripts/quick_validate.py)
- [Review generator](https://github.com/anthropics/skills/blob/33375500bcea98d610eb30ce10ac4e59b89c390d/skills/skill-creator/eval-viewer/generate_review.py)
- [Python select platform limits](https://docs.python.org/3/library/select.html#select.select)