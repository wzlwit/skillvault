# Power BI Modeling

Curated guidance for Power BI semantic-model design and review, including grain, relationships,
DAX, RLS, and validation. Start with [the skill instructions](SKILL.md).

Use supplied schemas for design without a live connection. Existing-model inspection or changes
require an identified target and appropriate authorization. The guide installs no MCP server,
connects to no model automatically, and does not publish reports or deploy models.

The default installation scope is global; project and session scopes are also supported.
Availability is not execution permission. Keep `kpi-dashboard` for metric definitions and layouts.

The [modeling guide](references/modeling.md) and [validation cases](references/validation.md)
are original curation, not vendored upstream manuals. They address the issues recorded in the
source evaluation. Provenance is pinned in the manifest; see [LICENSE](LICENSE).