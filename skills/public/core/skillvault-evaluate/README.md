# SkillVault Evaluate

Evaluate `<url|skillName> [location]` before deciding whether to upsert it. For a name with no
explicit location, it checks installed skills, local catalogs, the official SkillVault repository,
then external sources.

Examples:

```text
/skillvault-evaluate https://github.com/twpayne/chezmoi
/sv-evaluate schedule-manager
/sv-evaluate archify https://github.com/tt-a1i/archify
/skv-evaluate https://github.com/twpayne/chezmoi
```

This skill is read-only. It recommends `upsert`, `defer`, or `skip`; it does not create files
unless the user later invokes `/skillvault-upsert`.