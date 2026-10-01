# Power BI Modeling

Guidance for Power BI semantic-model design and review, including grain, relationships,
DAX, RLS, and validation, adapted from the GitHub Awesome Copilot skill. Start with
[the skill instructions](SKILL.md).

Use supplied schemas for design without a live connection. Existing-model inspection or changes
require an identified target and appropriate authorization. The guide installs no MCP server,
connects to no model automatically, and does not publish reports or deploy models.

The default installation scope is global; project and session scopes are also supported.
Availability is not execution permission. Keep `kpi-dashboard` for metric definitions and layouts.

The [modeling guide](references/modeling.md) and [validation cases](references/validation.md)
are SkillVault's own. The other reference files and the Original section of the skill come from
the original. Provenance is in the manifest; see [UPSTREAM-LICENSE](UPSTREAM-LICENSE).