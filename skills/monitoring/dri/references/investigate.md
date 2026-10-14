# Investigate an Incident

Contents: Inputs; Steps; The Brief; Query Practice; Profile Contents.

Use this procedure for `/dri investigate`, or an incident ID or link typed after `/dri`. It reads
and reports; it changes nothing. The project's DRI profile supplies every service-specific source,
query, signal, and owner (see the [skill rules](../SKILL.md#project-profile)).

## Inputs

- The incident ID or link, or the identifiers it carries: the affected tenant or organization, the
  job or run, and a correlation ID.
- When the impact started, and the environment or region.
- The project's DRI profile.

Ask only for what the incident itself doesn't carry.

## Steps

1. **Read the incident:** title, impact, severity, timeline, the full discussion, custom fields, and
   linked incidents. Note what people and automation have already done. If existing automation
   already handles this signature, report that and stop.
2. **Set the window:** compare the incident's age with the profile's retention limits, then set the
   query windows: around the failure, and from the failure until now for recovery.
3. **Rebuild the failing run:** its correlation ID, the steps it ran, where it stopped, and the full
   error chain. Say whether it started, failed a precheck, was suppressed, or exited right after
   starting.
4. **Check for recovery:** did a later run of the same work for the same target succeed, judged by
   the profile's success signal? A failure-handling step that runs on every run is not, by itself,
   a sign of failure.
5. **Extract the signature:** error code, exception type, status code, and any dependency's error
   code.
6. **Check configuration and readiness:** the records, settings, flags, and dependencies the profile
   lists for this kind of work.
7. **Check the scope:** the same signature on other targets in the same window separates one
   target's problem from a platform, rollout, or dependency problem.
8. **Find prior incidents** with the same target or signature, and how they were resolved.
9. **Find the runbook** for the signature.
10. **Classify:** match the profile's signature catalog to a category, an owner, a recommended
    action, and a confidence.
11. **Challenge the conclusion:** name what would disprove it, such as a later failed run, another
    component failing, or a spike across many targets, and check it.
12. **Write the brief.**

## The Brief

- **TL;DR:** the recommended action, the pattern, and the confidence.
- **Impact and timeline:** in UTC, each point with its source.
- **Facts:** each with its evidence, such as a query, a link, or a code location.
- **Hypotheses:** ranked, each with supporting and contradicting evidence.
- **Missing evidence:** what is missing and why, such as no access, past retention, or a failed query.
- **Next step:** the next diagnostic query, or a repair plan as a dry run with its rollback and
  verification. Mark every step that needs the DRI's approval.
- **Draft update:** a ticket comment or resolution note for the DRI to post. Never post it.

Keep the brief in chat unless the user names a file or the project has a place for DRI notes.

## Query Practice

- Query the store that holds the incident's region or partition directly. A fan-out across every
  region can fail or time out and return no rows, and no rows is not evidence.
- Filter on the target's identifiers and the job type before parsing large fields.
- Keep each window short enough to finish, and widen it in steps.
- Past the retention limit, say the evidence is gone instead of guessing.

## Profile Contents

A DRI profile, usually `dri-profile.md` in the working project, holds:

- The services and incident types it covers, and how to recognize each, such as title patterns.
- Evidence sources and how to reach them: telemetry stores and queries, the ticket system,
  deployment and change history, configuration stores, and code locations.
- Success and failure signals for each job type.
- The signature catalog: each signature's category, owner, runbook, and recommended action.
- Owners, routing, and escalation contacts.
- Operations a DRI may approve, each with its dry run, rollback, and verification.
- Retention and query limits.
- Existing automation, and the signatures it already handles.
