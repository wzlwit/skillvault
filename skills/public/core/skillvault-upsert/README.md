# SkillVault Upsert

Create or update a local SkillVault source skill from a name or source URL, then optionally
install it using the requested or manifest-defined scope.

When no local SkillVault repository is available, this skill asks whether to clone one into
`~/.copilot/skillvault-src` or create a remote pull request. It does not write SkillVault entries
into unrelated repositories.

Examples:

```text
/skillvault-upsert code-review
/skillvault-upsert https://github.com/twpayne/chezmoi project
/sv-upsert schedule-helper none
/skv-upsert https://github.com/twpayne/chezmoi default publish
```

Publishing is separate: this skill does not commit, push, or open a PR unless explicitly
asked.