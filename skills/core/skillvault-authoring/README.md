# SkillVault Authoring

Create or update a local SkillVault source skill from a name or source URL, then optionally
install it using the requested or manifest-defined scope.

The bundled [source resolver](scripts/resolve-source-repo.ps1) checks an explicit `--repo`,
the working project, the known Windows checkout `C:\repos\skillvault`, then the source cache.
It requires a SkillVault layout at the exact Git root and a verified `wzlwit/skillvault` origin.
An invalid explicit/preferred source blocks edits; it is not silently replaced. Source root,
catalog, and skill destination are displayed before authoring. Uncommitted work is preserved.

When no source is found, choose an explicit checkout or approve cloning into
`~/.copilot/skillvault-src` or a remote pull request. No source files are written into an unrelated
working project. An optional project installation still goes to that original project's
`.github/skills`, separately from source authoring. Resolution itself is read-only and uses
PowerShell 5.1+ or PowerShell 7 and Git, with no network calls.

The resolver reuses the sibling `skillvault-installation` bundle's verifier in Upsert mode. Keep that
declared dependency installed beside this skill; upsert's existing source selection is unchanged.

Examples:

```text
/skillvault-authoring upsert code-review
/skillvault-authoring upsert https://github.com/twpayne/chezmoi project
/skillvault-authoring upsert schedule-helper none
/skillvault-authoring upsert schedule-helper none --repo C:\repos\skillvault
/skillvault-authoring upsert https://github.com/twpayne/chezmoi default publish
```

`/skillvault-source` and `/sv-source` remain compatibility routes. Publishing is separate:
this skill does not commit, push, or open a PR unless explicitly asked.