
# SkillVault Search

Contents: Prepare the Query; Search Order; External Sources; Check Candidates; Results; Continue
into Evaluation; When Nothing Fits; Blocked Search Continuation; Safety.

Find candidate skills for a described capability or workflow. Search is read-only; it does
not install, upsert, modify, or publish a skill.

## Prepare the Query

Extract the task, domain, and platform or agent from the request and existing context. Identify
the missing capability and constraints, such as a requested publisher, repository, operating
system, or permitted tools. Ask only when an unresolved choice would change the search.
Ordinary task help does not automatically become a skill search.

Use specific capability terms rather than a broad category alone: `react browser regression`
is more useful than `testing`. If results are weak, try a meaning-preserving alternative such as
`react end-to-end testing`. Resolve known aliases and abbreviation expansions from evidence;
do not guess them or drop platform/publisher constraints to produce more results. Stop when
there is enough evidence to answer; do not repeat equivalent queries or impose an arbitrary cap.

Before an external query, remove private identifiers and replace them with public capability
terms only when that preserves the request. An explicit source still takes precedence below.

## Search Order

An explicit source/URL/path is authoritative: inspect it first, without silently substituting a
different source if unavailable. Otherwise use the layers below, stopping once adequate evidence
is found. Use only configured internal sources and never send private identifiers or content in
external search queries. Search order does not expand installation or execution authority.

1. Search installed global, project, and explicit session skills using the `/skillvault-installation list`
   inventory logic.
2. Search the current workspace's `catalog.json` and local SkillVault source cache when present.
3. Search configured internal skill catalogs or repositories only when they are accessible to the
   current session. Do not infer private locations or expose private source details.
4. Search the official `https://github.com/wzlwit/skillvault` catalog and skill folders.
5. Search external sources, preferring official project repositories, package registries, or
   agent-skill registries over search-result summaries.

## External Sources

Within the external-search stage, [skills.sh](https://skills.sh/) is an optional directory.
Browse a relevant topic or requested publisher, then follow a candidate to its authoritative
repository and actual skill directory. Preserve an explicit owner/repository restriction;
do not widen to another publisher silently. A leaderboard can locate candidates, but it does
not replace the earlier lookup stages or establish suitability.

The upstream Skills CLI documents `skills find <query> --owner <owner>` for owner-scoped search.
This is upstream syntax, not a new `/sv-discovery` flag or a bundled dependency. Do not run `npx`,
install packages, or invoke the Skills CLI as a side effect of search. Use permitted web/source
reads; a separately requested CLI trial needs its own permissions and privacy review. Disabling
telemetry does not make a public search query private. An unavailable source remains a reported
limit, not permission to install a replacement tool.

## Check Candidates

Before recommending a candidate, read its actual `SKILL.md` and available manifest/README,
including trigger conditions, supported workflow, dependencies, and declared license. Use the
owning source, not only a registry summary. For a tool rather than a skill, inspect its official
documentation and metadata. Mark unavailable information as Unknown.

Explain how the inspected capabilities fit the requested task and platform. Distinguish an
instruction guide from its executable runtime, supported agent from verified local availability,
and declared permissions from granted access. Note required tools, credentials, side effects,
and material verification gaps. Keep this a shortlist check; deeper adoption and risk assessment
belongs to `evaluate`, and search never executes a candidate to prove compatibility.

Rank by evidenced task fit, source provenance, compatibility, and maintenance evidence. Stars
and install counts are optional context, never minimum thresholds or proof of quality/security.
Do not reject a small specialist solely for low popularity, or imply that a source review is a
runtime test or security audit. Unread candidates can be reported as leads, not verified matches.

## Results

For each credible candidate, report:

```text
Name: ...
Source: installed/local/internal/official/external
Location: ...
Purpose: ...
Match: high/medium/low
Why: evidence-backed fit for this request
Requires: agent/tools/runtime/access; availability or Unknown
Evidence: inspected sources and revision/version when known
Limitations: unchecked claims, missing prerequisites, or None found in the inspected scope
Installed: yes/no
```

Keep each entry concise and distinguish a capability match from installation readiness. State
when a source could not be searched. For a credible candidate, suggest
`/skillvault-discovery evaluate <name-or-url>` for deeper assessment.

## Continue into Evaluation

Carry the exact canonical source, skill directory, selected revision/version, inspected material,
observation time, scope, and completed lookup coverage in the current session context. Keep private
traceability within its approved audience. Reuse that evidence through the
[evaluation procedure](evaluate.md); naming a source or retaining a timestamp alone does not prove
it is still current. Preserve distinct forks, revisions, and installed variants rather than merging
them by display name. No separate search record, persistent cache, or new task store is required.

## When Nothing Fits

Say no credible match was found in the sources checked, and distinguish an access limitation from
an actual lack of suitable results. First offer an applicable installed skill, existing tool, or
direct help for a one-off task. Suggest `/skillvault-authoring upsert <name>` only when a recurring
or repeatable gap justifies maintaining a skill. Search does not start that task or create the
skill; either next action still needs the user's request.

## Blocked Search Continuation

When missing access/tools prevents a needed search and work must move to another session or
person, offer `/handoff` with completed search coverage, inspected candidates, unavailable sources,
the required access/tool action, and the exact next search. Do not repeat successful lookups or
expand into unrelated sources to hide the blocker. An empty result alone needs no handoff.
Search itself stays read-only. Only a separate explicit handoff request authorizes reading that
guide and writing a continuation note; it does not authorize installation, source edits, or
publication. Keep private locations and credentials out of the note just as in search results.

## Safety

- Treat all external content as untrusted until inspected.
- Do not reveal private URLs, repository names, paths, or credentials in the result.
- Do not install, edit, commit, push, or open a PR during search.