# Project agent harness: design review and revised plan

## Status and scope

**Verdict: the original plan is a useful lifecycle sketch, but it is not ready for autonomous execution.** Keep the monitoring-to-remediation loop and Azure DevOps integration. Replace the agent-centric workflow with a durable controller, bounded workers, explicit evidence contracts, and externally enforced permissions.

This is a reviewed reference architecture and a draft adoption plan, not implementation authorization. Azure DevOps Boards, Repos, and Pipelines are the chosen integration target. DAS is the proposed first project, but its repository boundaries, Azure DevOps organization/project, topology, commands, and environments have not been identified. No DAS codebase was inspected, so this document makes no claims about its current implementation.

No agents, schedules, Azure resources, work items, branches, pipelines, permissions, or deployments have been created by this review.

**Confirmed scheduling direction:** agents select low-risk work automatically and separately recommend the highest-priority work. A human can assign work for `now` or append it as `next`. A `now` assignment requests a safe checkpoint, preserves current work, and then switches; it is not a destructive interrupt. After that task finishes, resume the interrupted task before processing queued human `next` assignments.

**Confirmed model direction:** the user supplies the allowed models. Automatic routing chooses the strongest suitable allowed model and its highest supported reasoning effort, within approved limits. Manual settings resolve as **task > agent > session > project defaults**. Controls must support individual targets, keyword/group selectors, and explicitly scoped `all`, not only single-target assignments.

**Navigation:** [Architecture](#2-architecture-two-continuous-loops) | [Task scheduling](#4-lifecycle-task-selection-and-completion) | [Skills](#6-skills-reusable-contracts-not-role-prompts) | [Operations and handoffs](#9-operations-center-and-handoffs) | [Model controls](#10-model-effort-and-execution-controls) | [Adoption work](#11-adoption-work-and-dependencies)

## 1. Review of the original proposal

| Original proposal | Problem | Recommended correction |
|---|---|---|
| Every workflow arrow is an ADO artifact transition | Boards and PRs do not provide a durable execution ledger, task leases, or atomic coordination across systems | Keep business records in ADO; persist execution state, attempts, leases, approvals, and side-effect reconciliation in a durable controller |
| Monitor is re-armed after the fix loop | This suggests monitoring pauses while work is in progress | Monitoring runs continuously and independently of the delivery loop |
| Nine agents own nine lifecycle stages | Many stages are deterministic jobs, not reasoning tasks; extra workers add cost and coordination failure modes | Start with a controller and a small pool of on-demand workers; tests and deployments remain controlled jobs |
| Repro evidence is mandatory before triage proceeds | An outage may be intermittent or not locally reproducible; an evidence gate must not delay incident response | Page and record observed impact immediately; require adequate investigation evidence before autonomous coding, with reviewed exceptions |
| One work item equals one PR | A cross-repository fix may need several coordinated PRs; unrelated changes should still be separated | Use a parent work package with dependent child tasks and one isolated session per coherent PR |
| Review blocks unless test coverage increases | Coverage percentage is a proxy and does not prove the original bug is fixed | Require a relevant regression scenario and appropriate impact coverage; document justified exceptions |
| Agent prompts or session-plan approval govern release permission | An agent can misunderstand policy, and a coordinator approving a child plan is not independent deployment authorization | Enforce tool scopes, branch policies, and environment approvals outside agent-editable instructions and code [R1] |
| PPE/prod testing, deployment, and rollback are one optional stage | Observation, active probes, deployment, and rollback have different side effects and permission requirements | Separate these operations; use protected pipelines and explicit environment-specific policies [R2] |
| Automatically roll back on regression | Data migrations and stateful changes may not be reversible; a noisy signal can trigger harmful action | Halt promotion first; automate only a specifically approved, tested recovery procedure |
| Log every agent decision as a WI comment | This creates noise and can expose sensitive logs or unnecessary agent transcripts | Store structured audit events and evidence securely; summarize meaningful transitions in ADO |

## 2. Architecture: two continuous loops

```text
CONTINUOUS OBSERVATION
Existing telemetry + E2E/synthetic results + CI/release events
    -> normalize, correlate, deduplicate
    -> immediate incident/on-call route when required
    -> candidate bugs, investigation tasks, or backlog evidence
    -> keep observing while remediation runs

CONTROLLED DELIVERY
Human assignments + approved low-risk backlog/monitor candidates
    -> readiness and risk assessment
    -> estimate, apply now/next scheduling, and claim
    -> implement in an isolated PR workspace
    -> independent review + executable validation
    -> human/policy-controlled merge
    -> existing or explicitly authorized release process
    -> observe the exact deployed version in the target environment
    -> verify, reopen, or escalate
```

High-severity incident handling is a separate fast path: notify the incident owner and follow an approved mitigation runbook. Do not wait for estimation, a local reproducer, or a new code PR. Do not interpret this fast path as permission for an agent to improvise a production action.

### Control plane and source-of-truth boundaries

| Information | Authoritative system |
|---|---|
| Work item ownership, business priority, acceptance criteria, dependencies | Azure DevOps Boards |
| Code, commit identity, PR discussion and merge status | Repository and Azure DevOps Repos |
| Actual build, automated test, artifact, and deployment outcomes | The runner/pipeline that executed them |
| Harness run state, task leases, retries, approval bindings, policy decisions, idempotency records | Durable workflow store |
| Telemetry and observed service health | The original monitoring system |
| Approved skills, project configuration, scenarios, references, policies | Version-controlled harness/project configuration |
| Approved model allowlists, routing defaults, and capability/evaluation catalog | Versioned model policy and verified runtime capability metadata |
| Human model/mode/effort assignments and selector rules | Authenticated controller configuration with revision and audit history |
| Current/history/handoff Markdown pages | Derived navigation views of the authoritative records above, not executable workflow state |

ADO is the human-facing record; the controller reconciles with it rather than treating comments or chat history as executable state. Human reassignment, closure, cancellation, or policy changes must invalidate or pause affected claims instead of being overwritten.

Use an existing supported workflow runtime if available. An Azure-native option is Durable Functions or Durable Task; another existing durable engine is acceptable. The runtime choice remains open. With a replay-based orchestrator, place LLM calls, network requests, and tool side effects in activities, not deterministic orchestration code [R3].

### Required execution guarantees

- Persist events and workflow state so a restart resumes work rather than redoing the entire loop.
- Assume at-least-once event delivery. Use deduplication, transactional local state, an outbox, and reconciliation; do not claim exactly-once execution across ADO, Git, and pipelines.
- Give each work package a durable claim with an owner, expiry, and monotonically increasing fencing token. Validate the current token at the mutation boundary.
- Record a stable operation ID before an external write. Reconcile unknown outcomes before retrying a WI creation, PR creation, pipeline queue, or deployment.
- Use ADO revision checks for read-modify-write operations. A search followed by create is not an atomic deduplication mechanism.
- Bound retries, repair iterations, concurrent work, tool calls, and resource consumption. Missing required limits block execution rather than selecting permissive defaults.
- Classify failures: transient infrastructure failure, reproducible product failure, missing evidence, unavailable environment, denied permission, or exhausted budget.
- Keep explicit paused, blocked, awaiting-approval, cancelled, and escalated outcomes. None counts as success.
- Provide a global kill switch and project/environment pause controls that workers cannot modify. A kill switch stops new work and invokes defined safe-stop behavior for in-flight operations.
- Publish current status, history indexes, and checkpoint handoffs through one version-aware projection service; stale workers must not overwrite newer views.

## 3. Team design

These are logical roles, not a requirement for separate always-on agents or different models.

| Role | Responsibility | Output and authority boundary |
|---|---|---|
| **Controller** | Durable state, scheduling, checkpoints, claims, model-policy enforcement, status projections, budgets, reconciliation | Validates agent model proposals and human overrides; delegates bounded work, not unrestricted authority |
| **Observer / triager** | Correlate signals, assess impact, collect evidence, route incidents, propose or update tasks | Structured finding; read-only telemetry plus narrowly authorized tracking writes |
| **Planner / estimator** | Assess readiness, scope, effort band, uncertainty, risk, dependencies, and validation needs | Separate low-risk execution selection and highest-priority recommendation; no authority to override eligibility policy |
| **Implementer** | Investigate and produce a scoped fix plus regression coverage | Branch/draft PR in an isolated project session; no production credentials, no self-approval |
| **Independent reviewer** | Review the actual diff, requirements, tests, risks, and evidence | Findings bound to a commit SHA; cannot silently change acceptance criteria or approve its own implementation |
| **Validator** | Run approved commands and scenarios, collect actual outcomes, classify failures | Evidence bundle from controlled runners; cannot turn skipped or inconclusive tests into passes |
| **Release / verification adapter** | Request an authorized release operation and correlate deployed artifacts with health | Protected pipeline operations and health evidence; optional release mutation capability |

For the first pilot, observation and planning can share a worker; implementation should retain a separate reviewer. CI execution does not need a separate conversational agent. Spawn extra workers only for genuinely independent work.

One child session should normally own one PR. A multi-repository work package can have several dependent PR sessions. Reuse the same PR session for review and CI repair rather than repeatedly spawning a new developer.

Independence is more than separate prompts: author and reviewer identities, permissions, branch policies, and approval rules must prevent self-approval. An AI review is advisory unless an explicit organization policy says it satisfies a required review.

## 4. Lifecycle, task selection, and completion

### Internal delivery states

```text
Proposed -> NeedsEvidence | Ready
Ready -> Queued -> Claimed -> Implementing
Implementing -> ReviewingAndValidating
ReviewingAndValidating -> Implementing | AwaitingMerge | Blocked
AwaitingMerge -> Merged -> AwaitingDeployment | AwaitingVerification
AwaitingVerification -> Observing -> Verified | Reopened | Escalated

ActiveWork -> PauseRequested -> Checkpointing -> Paused -> Resuming
Any applicable state -> AwaitingApproval | RetryScheduled | Cancelled | Superseded
```

These are harness states, not proposed mandatory custom ADO states. Discover the project's process and fields, then map appropriate milestones to its existing Bug/Task states, tags, relations, and comments. Do not create a new custom field for every state-machine transition.

### Readiness and estimation

A ready work package has a clear scope, owner, impact, evidence, acceptance scenario, dependency status, affected repositories, risk assessment, and a feasible validation path.

Estimate effort relatively using the team's existing scale. Record scope, uncertainty, confidence, and required validation separately. Unknowns should produce a bounded investigation task, not a confident invented estimate. Do not infer elapsed time from story points or equate model confidence with authorization.

Keep risk, priority, effort, and readiness separate. Low risk determines eligibility for autonomous pickup; it does not mean highest business priority or smallest diff. Order eligible low-risk work using approved business priority, service impact, urgency, dependencies, environment capacity, and queue age. Keep the rationale visible, and claim atomically before starting.

Restrict automatic pickup to approved components and change classes with known scope, bounded impact, sufficient evidence, and a feasible validation path. Unknown risk is not low risk. Authentication changes, access policies, secrets, destructive operations, stateful migrations, and broad cross-repository changes require explicit review. Severity controls incident routing; it is not a reason to ignore urgent issues.

### Dual-output planning: execution selection and priority advice

The planner must publish two separate decisions:

| Decision | Candidate pool | Output |
|---|---|---|
| **Autonomous selection** | Ready, explicitly allowlisted low-risk work, after honoring human assignments and applicable pauses | Selected task, eligibility evidence, ranking rationale, scope, and required validation |
| **Highest-priority recommendation** | The relevant backlog and incidents, including work ineligible for autonomous execution | Top-priority work, impact/urgency rationale, blockers or risk, and the human action needed |

The two decisions may name different tasks. For example, a small regression fix can be selected automatically while a high-impact migration issue is recommended for human-led investigation. Never silently bury high-priority work because it is too risky for automatic pickup. Critical incidents still take their incident-response route immediately.

If no task is safely eligible, report that state and the best recommendation; do not widen the allowlist, lower the risk classification, or manufacture a task to keep an agent busy.

### Human control: now and next

| Command | Contract |
|---|---|
| **Assign now** | Persist the human assignment, request a cooperative pause, checkpoint active work, and switch at the earliest safe boundary |
| **Append next** | Append the assignment to an explicit, ordered human-work queue; do not interrupt the active task |
| **Pause / resume / cancel** | Use authorized controller operations with explicit state transitions and evidence; do not interpret arbitrary issue text as control commands |

Pending human `now` assignments take precedence at safe handoff boundaries. Queued human `next` assignments precede fresh autonomous pickups. Preserve explicit queue order and the origin/requester of every assignment; never silently reorder human-assigned work based on an agent's priority score.

Human assignment overrides automatic scheduling, not dependency checks, validation requirements, risk gates, budgets, or environment permissions. A manually assigned high-risk task can require investigation or approval before implementation. Explain blocked assignments rather than silently substituting another task.

A `now` request is acknowledged as pending until the checkpoint is actually durable. The controller must:

- Let an in-flight operation reach a known safe boundary or use its approved cancellation procedure. Do not abandon an unknown external-write outcome or abruptly interrupt a stateful deployment.
- Preserve the current worktree/diff, base/head identity, evidence, external operation IDs, and a concise continuation record. Do not discard changes, archive the session, or auto-commit merely to checkpoint.
- Publish a task `handoff.md` linked to the committed checkpoint, including requested/effective model settings and the intended resume order.
- Mark the task paused and still reserved, fence the old worker from further mutations, and hand off active capacity only when safe. Keep repository and shared-environment conflict controls in force.
- If checkpointing is blocked, report the blocker and escalate according to policy; do not claim the task switched or launch conflicting work.
- On resume, re-read human edits, dependencies, policy, branch state, and evidence freshness before continuing. Reuse the preserved PR session rather than starting a duplicate fix.

**Confirmed resume order:** after a human `now` task completes, resume the interrupted task first, then process the ordered human `next` queue, then select fresh autonomous low-risk work. A new `now` request can trigger another safe-checkpoint handoff. Paused work must remain visible and must not be lost or silently superseded.

Example: task A is active; B and C were appended as `next`; H is assigned `now`.

```text
Checkpoint A -> H -> Resume and finish A -> B -> C -> Next eligible low-risk task
```

This ordering does not bypass readiness or authority gates. If resumption or a human assignment is blocked, expose the reason and preserve the queue position; any skip or reprioritization must follow an explicit authorized queue policy.

### Two different completion conditions

- **Delivery complete:** the accepted change has merged and met its required code/test gates, with release status recorded.
- **Operationally verified:** the relevant artifact is deployed in the affected environment and the original scenario plus required health indicators satisfy the approved verification policy.

A passing local run or merged PR cannot resolve a production incident by itself. If deployment is outside the harness, track the external release and continue monitoring. Link an incident to the delivery task rather than letting merge-time work-item transitions falsely mark the incident resolved.

## 5. Validation and environment design

| Gate | Required evidence | Failure handling |
|---|---|---|
| Baseline and reproducer | Original failing scenario or documented observed evidence; known baseline conditions | Missing repro becomes investigation or a reviewed alternative, not fabricated certainty |
| Unit / integration / build | Actual commands, outcomes, relevant regression coverage, and artifact/commit identity | Distinguish product defects from baseline or infrastructure failures |
| Local or localPPE | Environment fingerprint, fixtures, dependency versions, original scenario outcome, cleanup evidence | Unavailable or mismatched environment is blocked/inconclusive |
| CI and review | Required branch checks and independent review against the current PR head | New code invalidates affected evidence and stale review approval |
| PPE, if required | Approved target, exact artifact, scenarios, test results, impact limits | Do not promote when a required gate is skipped or inconclusive |
| Production observation | Deployed version correlation, telemetry freshness, original scenario, guardrail metrics, required observation/sample coverage | Missing telemetry is unknown health, not healthy |
| Active production probes, if enabled | Separate approval, allowlisted scenarios and test tenant, rate limits, isolation and cleanup | Never perform arbitrary writes against customer data |

Local, localPPE, and PPE are not interchangeable labels. The DAS profile must define what each environment contains, which dependencies are real or mocked, its data isolation, and what conclusions its tests can support.

Local tests execute code; an isolated Git worktree is not a security sandbox. Use an approved disposable or restricted runner without production credentials, and never execute agent-modified code in the user's primary repository checkout.

Prefer scenario-based regression evidence over a blanket coverage-percentage increase. Record flakes explicitly, use a bounded rerun policy, and do not weaken tests or quarantine a failure merely to obtain a green run.

Promotion and closure require exact commit/build/artifact provenance. A stale pass from another commit, environment, or fixture set does not satisfy a gate. Optional gates must be recorded as not required with a policy reason; they must not be reported as passed.

Health policies need meaningful service indicators, freshness requirements, required sample coverage, and observation criteria before they can authorize closure. Alerting should measure customer-visible reliability where possible, and account for low-traffic conditions rather than paging on every exception [R4].

Production rollback is a separate change. Default to stopping further promotion and escalating. Automated recovery is allowed only for an explicitly authorized, tested procedure with known compatibility constraints [R2].

## 6. Skills: reusable contracts, not role prompts

Separate three concepts:

1. **Role:** who is responsible for a decision or stage.
2. **Skill:** a versioned procedure with schemas, evidence requirements, allowed tools, and evaluations.
3. **Adapter/tool:** the executable integration that performs a specific operation and enforces authorization.

### Proposed skill catalog

Names below are design proposals, not claims that these skills are already installed.

| Skill | Inputs | Outputs / acceptance |
|---|---|---|
| `project-onboard` | Approved repository, service, environment, owner, and reference information | Validated project profile; unresolved fields remain explicit |
| `observe-correlate` | Signal events, service indicators, release context, existing findings | Normalized finding, correlation key, impact evidence |
| `triage-work-item` | Finding, routing policy, ADO process metadata | Deduplicated linked work item or incident route; uncertainty preserved |
| `estimate-plan` | Task, repository context, dependencies, validation options | Effort band, risk, uncertainty, readiness, decomposition, low-risk selection and separate highest-priority recommendation |
| `dispatch-control` | Authenticated now/next/pause/resume requests, queue and lease state | Durable ordered assignments, safe checkpoint handoff, explicit blocked/pending outcomes |
| `select-model` | Allowed catalog, task/role requirements, scoped overrides, quotas and budgets | Validated model/effort selection, assignment provenance, or an explicit blocked decision |
| `checkpoint-handoff` | Verified task state, worktree identity, evidence, pending operations, queue context | Durable checkpoint and concise resumable handoff; no fabricated completion or new authority |
| `publish-status` | Committed events, task/agent state, telemetry freshness, routing decisions | Consistent current pages, history indexes, and evidence links; normally a deterministic projection job |
| `implement-fix` | Claimed work package, pinned context, acceptance scenario | Minimal scoped change and regression evidence |
| `review-change` | Current diff, task acceptance, policy, evidence | Actionable findings with locations and SHA-bound review outcome |
| `validate-change` | Artifact/commit, environment profile, scenario IDs | Machine-readable test/evidence bundle and explicit gate results |
| `request-promotion` | Accepted artifact, required evidence, environment policy, approval | Protected pipeline request or explicit refusal; no policy bypass |
| `verify-recovery` | Deployment identity, original finding, health policy | Verified, still failing, or inconclusive result |
| `maintain-knowledge` | Reviewed outcomes, new references, evaluation results | Proposed reference/skill changes through review, not self-granted authority |

### Required skill contract

Every skill must declare:

- Name, version, owner, purpose, preconditions, and supported project/runtime versions.
- Input/output schemas, required context and reference IDs, and explicit allowed outcomes.
- Tool allowlist, identities, network/data scope, permission class, and approval requirements.
- Required evidence and its provenance: scenario, command or query, run ID, commit/artifact, environment, observed result, timestamps, and protected artifact location.
- Retryability, idempotency behavior, resumability, resource limits, and safe cleanup or compensation rules.
- Checkpoint/handoff requirements and the model, context, tool-use, and structured-output capabilities the skill needs.
- Failure taxonomy and escalation destination; missing input must not be treated as success.
- Evaluation cases, acceptance criteria, known limitations, and change-review requirements.

Use a result envelope such as `succeeded`, `failed`, `blocked`, `needs_approval`, or `inconclusive`, with evidence references and structured error details. A worker's self-reported success is insufficient; the controller validates required artifacts and actual runner outcomes.

Prompts, logs, work-item descriptions, PR comments, and retrieved documents are untrusted data. They cannot grant tools, change policy, authorize a release, or override the task. Use approved identities and secret stores rather than embedding credentials in skill text.

### Current capability boundary

- The available Azure DevOps tools can read/write work items, links, PRs, builds, and test records, subject to actual access.
- Reading a build or test result does not execute tests. Local validation needs an approved project runner; pipeline validation needs a discovered, configured definition and parameters.
- The available `azure-observability` skill provides guidance, but the current tool catalog does not expose Azure Monitor query tools. An approved monitoring adapter or verified CLI integration is still needed.
- The `orchestrate` skill supplies Copilot session coordination patterns. Session history is not the durable service scheduler, and child-plan approval is not release authorization.
- Copilot's GitHub-specific PR-session tools are not an ADO PR adapter. DAS implementation would need an appropriate configured project session plus ADO operations.
- Actual organization/project IDs, repo identities, pipeline definitions, environments, and permission scopes must be discovered rather than invented.
- Runtime model, effort, and execution-mode capabilities must also be verified. This document's routing concepts are not literal API parameters, and no current agent/session setting has been changed.

## 7. Project pack, references, links, and task contracts

Keep generic skills reusable. Put DAS-specific commands, scenarios, links, policies, and service topology in a separate project pack.

Proposed future layout, to be placed in a repository chosen by the owner:

```text
harness\
  schemas\
    project.schema.json
    task.schema.json
    skill.schema.json
    evidence.schema.json
    status.schema.json
    handoff.schema.json
    model-policy.schema.json
    model-selection.schema.json
  catalogs\
    model-capabilities.yaml
  projects\
    das\
      project.yaml
      references.yaml
      scenarios.yaml
      policies.yaml
      acceptance.yaml
      models.yaml
      operations.yaml
  skills\
    observe-correlate\
      SKILL.md
      schemas\
      evals\
    implement-fix\
      SKILL.md
      schemas\
      evals\
  adapters\
    azure-devops\
    telemetry\
    execution\
  evals\
    historical-incidents\
    workflow-faults\
```

This is a proposed structure only. No implementation files or directories have been created.

### Project and reference registry

The project profile should include service boundaries, repositories, ADO organization/project and area mappings, owners/on-call route, environment definitions, approved commands and pipelines, test data policy, and service health objectives.

Each reference needs a stable ID, type, URL/path, owner, applicable component/environment, trust classification, revision or content hash when available, access classification, last verification, and freshness policy. Resolve only task-relevant references; do not dump the entire knowledge base into each agent prompt.

Pin the profile, skills, policies, and reference versions used by a run. Missing or stale critical references block the dependent action; optional references can be omitted with a recorded reason. Retrieved content can inform evidence but cannot override trusted policy.

| Reference ID example | Expected content | Current status |
|---|---|---|
| `das-architecture` | Service boundaries, dependency graph, ownership | Required; not supplied |
| `das-repositories` | Configured projects and authoritative repository URLs | Required; not mapped |
| `das-observability` | Dashboards, saved queries, SLIs/SLOs, alert routing | Required; not supplied |
| `das-local-validation` | Build/test commands, bootstrap requirements, fixtures | Required for coding pilot; not supplied |
| `das-localppe` | Definition, provision/reset/cleanup contract, access | Required if used; not supplied |
| `das-release` | Pipeline definitions, environments, approvals, recovery runbooks | Required before release integration; not supplied |
| `das-acceptance` | Representative E2E journeys and evidence expectations | Required; not supplied |

Do not store secrets or unrestricted customer payloads in references, task comments, or attachments. Preserve access controls, redaction, and retention requirements on evidence.

### Work package contract

| Group | Required information |
|---|---|
| Identity and provenance | Schema version, work package ID, ADO work item IDs, source finding IDs, correlation key |
| Scope | Goal, non-goals, component/repositories, owner, affected environments, dependencies |
| Readiness and selection | Observed impact, priority, effort band, uncertainty, risk tier, eligibility decision and rationale |
| Scheduling and human control | Assignment origin/requester, now/next mode, queue sequence, selected versus recommended status, checkpoint identity, paused task and resume policy |
| Model and execution control | Requested and resolved model, reasoning effort and execution mode; setting source per field; matched rule IDs; catalog/policy revision; currently executing settings |
| Acceptance | Scenario IDs, expected results, required gates, approved exceptions and approvers |
| Execution context | Profile/skill/policy versions, reference IDs, base/head SHA, artifact identity, runner/environment fingerprint |
| Control | Workflow run ID, lease/fencing token, operation IDs, attempt/resource limits, approval bindings |
| Evidence and audit | PR/build/test/deployment links, structured results, concise decision rationale, verification outcome |
| Navigation and continuation | Stable current/history/handoff links, checkpoint ID and source revision, prior/next owner, pending operations and resume preconditions |

Keep established ADO fields native where possible. Use relations, concise template sections, and links to structured artifacts for the rest. Confirm supported types and fields before introducing any custom process fields.

Maintain the traceability chain:

```text
Signal / incident -> parent work package -> child task(s) -> PR(s)
    -> exact commit -> build artifact -> test runs -> deployment
    -> post-deployment health evidence -> verification or reopening
```

Bulk logs and execution audit records belong in controlled artifact storage, not a stream of WI comments. Store decisions and evidence, not hidden model reasoning.

## 8. Permission and autonomy model

Use separate least-privilege identities for telemetry reading, tracking writes, source changes, validation, and release operations. An implementer must not hold environment-admin permissions or be able to edit the policy protecting its own run.

Approvals should bind the action, target, environment, commit/artifact, policy version, approver, and validity conditions. Changed code or an incompatible context change invalidates approval. Agents cannot approve themselves or weaken checks to proceed.

Azure Pipelines approvals/checks should protect the actual environments and service connections, not just rely on instructions or YAML conditions that the author can modify [R1].

| Adoption mode | Permitted scope after authorization | Still outside autonomous authority |
|---|---|---|
| **Shadow** | Read data, generate proposed findings/plans/evidence | ADO/repo writes, task pickup, merge, deploy |
| **Human-assigned PR work** | A human assigns now/next; agents investigate, implement, validate, and prepare a draft PR under approved scopes | Independent required review, merge, deployment |
| **Allowlisted auto-pick** | Claim eligible low-risk tasks, separately recommend highest-priority work, and run the approved draft-PR workflow | Restricted change classes, policy changes, unapproved environments |
| **Gated environment integration** | Separately authorized PPE validation or release requests through existing checks | Arbitrary production writes, approval bypass, improvised rollback |

**Selected delivery behavior: low-risk autonomous pickup plus highest-priority recommendations and human now/next assignment.** The user also selected safe-checkpoint preemption for `now`. Validate this behavior in read-only replay/shadow mode before enabling writes. Merge, release, and environment authority remain separately gated; they have not been authorized by these scheduling decisions.

## 9. Operations center and handoffs

### A single entry point, with indexed history

Use **both** a small `history.md` index and partitioned history folders. Do not grow one unbounded Markdown log or scatter unrelated status documents across agent worktrees.

The following is a proposed logical layout under a configured durable operations-storage root. It is separate from the source/configuration repository and survives an individual session or worktree being retired. It could be rendered by a local viewer or an authenticated shared service; the actual storage and hosting remain onboarding decisions.

```text
harness-state\
  das\
    README.md
    current.md
    history.md
    tasks\
      <task-id>\
        current.md
        handoff.md
    agents\
      <agent-id>\
        current.md
        handoff.md
    history\
      <year>\
        <month>\
          index.md
          <record-id>\
            summary.md
            events.jsonl
            evidence.json
            handoff.md
```

The agent-level and historical `handoff.md` files are conditional, not files to create for every trivial tool call. No operations directories or simulated live status have been created by this design update.

| Page/artifact | Purpose |
|---|---|
| `README.md` | Stable navigation to current status, history, project references, dashboards, and control entry points |
| Project `current.md` | The current service/monitor health, harness health, active work, human queues, paused work, recommendations, gates, and blockers |
| Project `history.md` | Recent meaningful outcomes and checkpoint links plus links to older partition indexes |
| Task `current.md` | Task scope, owner, lifecycle, current settings, PR/test/deployment links, latest handoff, and related history |
| Task `handoff.md` | Latest committed continuation checkpoint for that task |
| Agent `current.md` | Role, assigned tasks, active session, effective model/effort/mode, heartbeat, and pending configuration changes |
| Agent `handoff.md` | Only for transferable long-lived responsibilities, such as a monitor's committed cursor or a coordinator's outstanding operation references |
| History record | Immutable finalized summary/checkpoint, bounded redacted event export, and evidence references with provenance |

Every detailed page should link back to the project `current.md` and to its relevant task, agent, work item, PR, and history records. Use stable machine-safe IDs in paths, not mutable titles or untrusted path fragments.

### What belongs on current status

Show service health and harness health separately. Include source observation time, generation time, source revision/event position, and freshness status. A quiet or disconnected monitor is not evidence that the service is healthy.

Keep the page concise: selected low-risk work; the separate highest-priority recommendation; active/paused tasks; human `now`/`next` order; pending approvals and blockers; current and pending model/effort/mode settings; and links to evidence. Detailed logs belong behind those links.

Agents emit structured events and checkpoint proposals. The controller validates them; a single logical writer publishes the views atomically or with conditional version writes. An old worker or delayed snapshot cannot replace a newer status page. Rendered views identify their source revision so inconsistent or stale reads are detectable.

Generated Markdown is a view, not a command channel. Add tasks and references through ADO, the approved project registry, or authenticated controls. If human annotations are needed, keep them separate from generated fields so refreshes do not overwrite them.

### History and log rules

Publish history on meaningful transitions: task selection or manual assignment, pause/resume, model/effort/mode changes, review outcomes, validation, deployment/verification, and escalation. Do not put every polling event into `history.md`.

Finalized record directories are immutable; a correction creates a superseding record. Partition indexes and current pointers remain rebuildable projections. Each record includes task/run/agent IDs, actual event times, source revisions, artifact/environment identity, outcome, and concise decision rationale.

`events.jsonl` is an optional redacted export of a bounded event range, not a second authoritative event store. Large logs and evidence remain in their approved storage with access-controlled links. Do not publish secrets, customer payloads, or hidden model reasoning.

Configure retention, redaction, access control, and archive behavior in `operations.yaml`. Keep the same access restrictions across source evidence and its summaries. Approved retention expiry should leave an explicit expired-record indicator rather than a misleading broken link.

### Task-first handoff policy

Require a durable handoff before a resumable task is paused for human `now` work, transferred to a different worker/session/model, or deliberately stopped for context/resource limits. After a crash, reconstruct the handoff from committed state and reconciliation; never assume the crashed worker's last message is a complete checkpoint.

The task owns the primary handoff. An agent-level handoff should reference its tasks and durable responsibility state rather than duplicating all task narratives. Stateless short-lived jobs do not need an additional agent handoff.

The machine-readable checkpoint is authoritative; `handoff.md` is its navigable rendering. Link the file to the exact checkpoint ID, schema version, source revision, and archive record. Publish the current handoff pointer only after the checkpoint and required work artifacts are durable.

A handoff must contain:

- Task identity, objective, acceptance criteria, current state, and why the handoff occurred.
- Repository/worktree/session identity, base/head SHA, preserved change location, and applicable environment/artifact identity.
- Completed facts and evidence, clearly separated from hypotheses and unverified claims.
- Running or uncertain external operations, operation IDs, and required reconciliation before any retry.
- Blockers, unresolved review findings, required approvals, and policy/skill/reference versions.
- Requested, resolved, and currently executing model/effort/mode, including assignment/rule provenance.
- The next safe action and its preconditions, intended recipient, queue/resume position, and protected evidence links.

On resume, verify the checkpoint and actual repository/external state before acting. A stale handoff can help investigation but cannot authorize a mutation. A reviewer receives acceptance criteria, the actual diff, and verifiable evidence, and still performs an independent review rather than inheriting the author's conclusion.

## 10. Model effort and execution controls

### User-controlled allowlist and quality-first routing

The user supplies exact model/provider identifiers and can narrow availability by project, session, agent, or task. Applicable restrictions combine as hard constraints; a lower scope cannot silently broaden a higher-scope allowlist. An absent local restriction inherits its parent; an explicitly empty effective allowlist permits no model.

**Confirmed automatic behavior:** choose the strongest suitable allowed model and its highest supported reasoning effort, subject to the user's approved limits. "Best fit" includes the task's required tools, structured outputs, context, modality, data-processing restrictions, and role-specific quality evidence. Do not rank models by their names or assume one model is universally strongest.

Maintain a reviewed capability/evaluation catalog rather than hard-coding rankings into each skill. Agents can recommend a model and explain fit; the controller validates it against the allowlist, host capabilities, requirements, and budget. If quality or capability information is insufficient, surface that uncertainty instead of inventing a ranking.

`max_supported` is a harness policy concept, resolved to the selected provider/model's actual supported effort value. Never send it as an unsupported literal to a runtime API. For a model without an effort control, report that capability as not applicable; an explicit unsupported human effort request must be rejected, not silently ignored.

Maximum power does not mean unlimited agents, context, retries, or spending. Resource and data-access limits remain hard gates. Routine deterministic operations, such as formatting status pages or querying run state, do not need an LLM.

### Separate controls and inheritance

| Control | Meaning |
|---|---|
| `model` | A specific allowed model, or explicit automatic routing |
| `reasoning_effort` | A supported concrete effort, or automatic resolution to the highest supported level |
| `execution_mode` | Host-supported planning, interactive, or autonomous execution behavior; separate from model intelligence |
| Context requirements | Required input/context capability and any explicit user context-tier setting, validated against the host/model |

Resolve each field independently using the confirmed precedence:

```text
Task override -> Agent override -> Session override -> Project defaults
```

An unset field inherits. An explicit automatic value re-enables routing for that field at that scope; it does not erase manual values for other fields. For example, an agent-level model override can coexist with a task-level effort override.

Validate the final combination after inheritance. A permitted model paired with an unsupported effort is still invalid. Higher model capability or maximum effort never enables more tools, changes execution mode, or bypasses approvals.

The current page and handoff must show requested settings, resolved settings and their per-field sources, and the settings actually in use. Changing a session default can leave a more-specific task override unchanged; that must be visible, not surprising.

### Bulk and pattern-based overrides

Support all of the following selectors, not just individual IDs:

| Selector | Intended use |
|---|---|
| Exact task/agent/session IDs | Pin a particular work item or execution context |
| Keyword | Match declared fields such as task title, labels, component, or agent name; use documented case-insensitive literal matching by default |
| Named group | Select explicit or rule-defined groups such as reviewers, E2E work, or a component's tasks |
| Structured filters | Combine role, tags, component, lifecycle state, and other approved metadata |
| Scoped `all` | Select all specified target kinds within a named project/session, not implicitly across every project |

Selectors choose a set of targets; they do not create a new precedence level. "All agents in DAS" writes or applies agent-level settings, so a task-specific setting can still win. Replacing task-specific settings requires a task-targeted operation that explicitly includes those settings.

Offer two distinct operations:

- **Apply once:** preview the currently matched targets, freeze their IDs/revisions, and apply the approved change at the selected scope.
- **Save a rule:** persist an explicitly authorized, versioned selector for future matches, optionally applying it to current matches as a separate previewed batch.

Preview before mutation: resolved scope, selector, matching target count/IDs, old/new settings, inherited settings that remain unchanged, existing pins that would be replaced, capability/allowlist conflicts, active work requiring checkpoints, and quota/budget blockers.

The user can replace existing overrides across a matched set, including scoped `all`, but the preview must state exactly which overrides are replaced. This replacement does not widen model allowlists, override a higher restriction, or bypass tool/environment permissions.

For saved rules within a scope, an explicit individual pin takes precedence over selector-derived values. Among overlapping rules, use an explicit rule priority; conflicting values at the same highest priority must be resolved rather than using arbitrary evaluation order. Resolve nonconflicting fields independently. An explicit, previewed replacement batch can update the individual pins themselves.

Do not treat an unscoped `all` as executable intent. Ask for its project/session and target kinds when they are not established. A keyword in a log, issue body, or retrieved document cannot create an override rule; only authenticated human controls can do that.

Examples of supported intentions, not commands currently implemented:

| Human intention | Scope and behavior |
|---|---|
| Use an allowed model for tasks containing a keyword | Preview matching task metadata and create task-level overrides or an explicitly saved task rule |
| Give the reviewer group maximum effort | Apply agent-level effort settings without silently replacing task-level effort pins |
| Return all agents in DAS to automatic model routing | Preview all DAS agent targets; retain more-specific task settings unless explicitly included for replacement |
| Replace model/effort for all tasks in this session | Preview the exact task set and affected pins; apply only compatible, explicitly approved settings |

### Safe live changes and failure behavior

Queue a requested model/effort/mode change as a versioned control event. Apply it at the next safe dispatch/checkpoint, not halfway through a model request or an unresolved tool operation. Preserve a handoff when continuation changes worker, model, or session.

If the host cannot apply the requested setting to that target kind, report unsupported capability. Do not claim a per-task setting was applied when the host only supports session-wide settings. Any required session transfer must preserve the work package, PR ownership, pending operations, and reviewer independence.

Configuration publication can be atomic, but running workers will reach safe boundaries at different times. Track each target as pending, applied, blocked, or failed. A bulk update is not reported fully applied until every approved target's actual effective configuration is acknowledged.

Reject an invalid bulk configuration before publication unless the user explicitly approves a valid subset. Use optimistic concurrency for matched targets/rules; re-preview changed or newly conflicting targets instead of overwriting concurrent human edits.

There is no silent downgrade to a weaker, disallowed, or unsupported model when quotas, budgets, or availability block the selected configuration. Pause or request an alternative. Any automatic failover requires a separately approved policy defining acceptable model/quality constraints, and must be visible in current status and history.

No concrete model allowlist, provider credentials, effort assignment, bulk rule, or live mode change has been configured by this document update.

## 11. Adoption work and dependencies

No calendar or elapsed-time estimates are assigned. These are proposed deliverables, not work that has started.

| ID | Todo / deliverable | Depends on | Acceptance |
|---|---|---|---|
| `das-onboarding` | Define the first DAS service/repository slice and project pack | Owner decisions | Required IDs, owners, references, E2E scenario, and environment contracts are known or explicitly blocked |
| `harness-policy` | Define autonomy, model/data scopes, approvals, budgets, retention, and safe-stop behavior | `das-onboarding` | Unauthorized operations are denied outside agent prompts; authority and storage boundaries are reviewable |
| `harness-contracts` | Version task, skill, evidence, status, handoff, model-policy, and adapter schemas | `das-onboarding`, `harness-policy` | Missing/stale context, unsupported settings, and malformed results are rejected explicitly |
| `harness-controller` | Implement durable state, claims, idempotency, cancellation, and reconciliation | `harness-contracts` | Restart and duplicate-event scenarios do not create duplicate active work or uncontrolled repeated writes |
| `harness-handoffs` | Implement task checkpoints, handoff rendering, history links, and resume verification | `harness-controller` | A fresh worker can reconcile and resume without losing changes, duplicating operations, or inheriting invalid authority |
| `harness-model-routing` | Implement allowlists, maximum-power routing, scoped overrides, bulk selectors, and saved rules | `harness-controller` | Confirmed precedence and per-field inheritance hold; unsupported/disallowed combinations are blocked; bulk effects are previewed and acknowledged |
| `harness-dispatch` | Implement low-risk selection, priority advice, and human now/next controls | `harness-controller`, `harness-handoffs`, `harness-model-routing` | Human ordering is honored, preemption preserves work, and no selection bypasses permissions or readiness |
| `harness-observation` | Implement telemetry ingestion, correlation, triage, and ADO projection | `harness-controller` | Representative signals route correctly; incidents do not wait for code workflow readiness |
| `harness-ops-navigation` | Publish the central current page, linked task/agent views, and indexed immutable history | `harness-observation`, `harness-dispatch` | One entry point reaches current work, handoffs, model settings, and evidence; stale views are visible and cannot overwrite newer ones |
| `harness-validation` | Implement approved local/localPPE and CI validation adapters | `harness-contracts` | Real scenario results are bound to environment and artifact; blocked/skipped results cannot satisfy required gates |
| `harness-evaluation` | Replay historical/synthetic cases and exercise workflow, routing, and projection faults | `harness-dispatch`, `harness-observation`, `harness-validation`, `harness-ops-navigation` | Defined safety and quality acceptance suite passes before enabling writes |
| `harness-delivery-pilot` | Exercise one low-risk fix, now/next handoff, central navigation, and scoped model override | `harness-evaluation` | Original-scenario evidence connects to the change; a fresh continuation uses the correct settings and exposes its history |
| `harness-environment-gates` | Optionally integrate protected PPE/release requests and recovery verification | `harness-delivery-pilot` | Exact environment scope and approvals are provided; promotion and recovery controls are exercised |
| `harness-expansion` | Decide whether to widen allowlists, concurrency, or project/change-class scope | `harness-delivery-pilot` | Reviewed pilot outcomes and policy-specific acceptance justify the additional authority |

Start with one meaningful E2E journey and one coherent repository slice, not an entire product fleet. Expand only after the relevant quality, operational, and permission criteria have been demonstrated.

### Required evaluation cases

- Replayed and concurrently delivered signals produce the intended single active finding/work package.
- Worker crashes before and after an external write are reconciled without blind resubmission.
- Lease expiry, stale workers, concurrent human edits, and task cancellation prevent stale mutations.
- An outage or expired credential is reported as blocked; it is not converted into healthy telemetry.
- Untrusted issue text or a retrieved runbook cannot grant permissions, disclose secrets, or trigger arbitrary commands.
- A new commit invalidates affected review/test evidence; wrong-environment and wrong-artifact passes are rejected.
- A flaky or unavailable test does not become a false pass through unlimited retries.
- Denied/expired approvals, required skipped gates, budget exhaustion, and kill-switch activation halt the appropriate work.
- A high-severity incident reaches the incident route without waiting for estimation or local reproduction.
- A merged but undeployed fix cannot close an operational incident.
- A stateful/nonreversible change cannot trigger an unapproved generic rollback.
- Autonomous selection chooses only ready, allowlisted low-risk work while separately surfacing higher-priority work that requires human attention.
- A human `now` assignment during implementation, validation, or an external write switches only after a durable safe checkpoint.
- After `now` finishes, interrupted work resumes before ordered human `next` assignments, which precede fresh autonomous work; blocked assignments are explicit.
- Paused work retains its changes and reservation; resumption rejects stale leases, policy, branch state, or evidence.
- Assignment through a human control channel changes scheduling without granting new tool or environment authority.
- Concurrent or delayed status writers cannot overwrite a newer view; missing monitor/controller heartbeats display stale or unknown state.
- Navigation reaches each task's handoff and history, and returns to the central current page; finalized history is not silently rewritten.
- A resumed task reconciles a handoff's pending external operations and validates actual worktree state before retrying.
- Automatic routing chooses a verified suitable allowed model at its highest supported effort, or explicitly blocks when constraints cannot be met.
- Task, agent, session, and project settings resolve independently per field in the confirmed order.
- Keyword, group, and scoped-all previews identify exact current targets, unchanged higher-precedence pins, and invalid combinations.
- Conflicting saved rules, stale target revisions, unsupported host settings, and disallowed models produce explicit errors rather than arbitrary fallback.
- Broad replacement of existing pins requires the corresponding scoped preview/authorization; saved rules do not silently become global policy.
- Live bulk changes remain pending until safe-boundary acknowledgements; status/history/handoffs show requested and actual settings separately.

Measure signal precision, deduplication effectiveness, detection and recovery performance, successful verified fixes, reopened incidents, review defects, flaky tests, human interventions, policy violations, and resource cost per verified outcome. Establish service-specific acceptance thresholds before increasing authority. Avoid optimizing for ticket count, generated code, or PR volume.

Changes to models, prompts, skills, policies, or critical references should trigger relevant regression evaluations before adoption. Learning produces reviewable proposals; it must not silently broaden permissions.

## 12. DAS implementation prerequisites

- What DAS includes and which repository/E2E journey forms the first bounded slice.
- Exact meaning, availability, and isolation guarantees of local and localPPE.
- Workflow host and configuration repository, preferably reusing an existing supported platform.
- Service-specific budgets, severity mappings, health acceptance, and escalation ownership.
- Operations-storage root/hosting, readers/writers, freshness policy, redaction, retention, and reference-link access.
- The user's concrete allowed model/provider list, verified host capabilities, reviewed model-quality criteria, and project mode defaults.
- Whether any PPE action, deployment action, or active production test belongs in the initial scope.

The scheduling design above is confirmed. These project-specific inputs and implementation choices remain open rather than being presented as discovered facts. Resolve them before turning this reviewed reference design into a DAS-specific executable implementation plan. The review does not authorize beginning implementation.

## References

- **[R1] Azure Pipelines approvals and checks:** https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals?view=azure-devops
  - Resource-owned checks and environment approvals are separate from author-controlled YAML.
- **[R2] Azure Well-Architected: safe deployment practices:** https://learn.microsoft.com/en-us/azure/well-architected/operational-excellence/safe-deployments
  - Progressive exposure, health gates, and stopping deployment when health degrades.
- **[R3] Durable orchestrator code constraints:** https://learn.microsoft.com/en-us/azure/durable-task/common/durable-task-code-constraints
  - Deterministic replay and separation of orchestration from nondeterministic activities.
- **[R4] Google SRE Workbook: alerting on SLOs:** https://sre.google/workbook/alerting-on-slos/
  - User-visible reliability, actionable alerting, and low-traffic considerations.

These public references support the design principles; they do not establish DAS-specific readiness, permission, or configuration.
