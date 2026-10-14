# Skill Discovery

Search installed skills, local catalogs, accessible internal sources, the official SkillVault
catalog, and external sources for a requested capability. Results include source provenance and
links. Alone, the skill shows past evaluations and asks what to look for, without remote searches.
Search and explanation are read-only; completed evaluations save a public-safe record in the
verified SkillVault checkout under `docs/evaluations/` unless chat only is requested. No target
skill or installed copy is modified.

`explain` is the one menu word; exactly 3 or 4 of its leading letters also select it. Anything else
is text: a purpose searches, and a URL or one skill name is evaluated. Input that could be either
searches and offers to evaluate. Matching does not abbreviate other arguments or change approval
rules. Evaluation separates standalone usefulness, the SkillVault guide decision, and harness
integration when relevant; `upsert/defer/skip` applies only to the guide. Trying a standalone app
and integrating it are separate recommendations, neither authorizing execution.

Explanation accepts a skill, tool, or product. It explains the requested subject first, then
distinguishes any related installed guide and unverified runtime availability. Updating these
source files does not refresh installed copies; preview and approve that separately.

```text
/skillvault-discover
/skillvault-discover find a skill for API contract testing
/skillvault-discover persistent planning
/skillvault-discover https://playwright.dev/
/skillvault-discover explain playwright
```
