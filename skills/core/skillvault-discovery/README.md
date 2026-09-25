# Skill Discovery

Search installed skills, local catalogs, accessible internal sources, the official SkillVault
catalog, and external sources for a requested capability. Results include source provenance and
links. Bare invocation lists known context/actions without remote searches. Search and explanation
are read-only; completed evaluations save a public-safe record in the verified SkillVault checkout
under `docs/evaluations/` unless `--chat-only` is requested. No target skill or installed copy is modified.

Exact actions and documented aliases take priority, including `eval` and `expl`. Otherwise,
exactly 3 or 4 leading letters select one matching canonical action in this topic: `eva` selects
`evaluate`, and `exp` selects `explain`. Multiple matches require a choice; no match shows help;
neither executes an action. This does not abbreviate other arguments or change approval rules.
Full names remain in menus. Evaluation separates standalone usefulness, the SkillVault guide
decision, and harness integration when relevant; `upsert/defer/skip` applies only to the guide.
Trying a standalone app and integrating it are separate recommendations, neither authorizing execution.

Explanation accepts a skill, tool, or product. It explains the requested subject first, then
distinguishes any related installed guide and unverified runtime availability. Updating these
source files does not refresh installed copies; preview and approve that separately.

```text
/skillvault-discovery search find a skill for API contract testing
/skillvault-discovery search API contract testing
/skillvault-discovery search persistent planning
/skillvault-discovery evaluate https://playwright.dev/
/skillvault-discovery explain playwright
```