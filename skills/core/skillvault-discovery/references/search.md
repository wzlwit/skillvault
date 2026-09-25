
# SkillVault Search

Find candidate skills for a described capability or workflow. Search is read-only; it does
not install, upsert, modify, or publish a skill.

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

## Results

For each credible candidate, report:

```text
Name: ...
Source: installed/local/internal/official/external
Location: ...
Purpose: ...
Match: high/medium/low
Installed: yes/no
```

Rank results by match and trust. State when a source could not be searched. For a candidate,
suggest `/skillvault-discovery evaluate <name-or-url>` for deeper assessment. When no credible candidate is
found, report the search limits and suggest `/skillvault-authoring upsert <name>` to create a native skill.

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