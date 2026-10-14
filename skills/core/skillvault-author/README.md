# SkillVault Authoring

Create or update a local SkillVault source skill from a name or source URL. It never installs;
use `/skillvault-install <name>` for installed copies. Alone, it confirms a target that is clear
from the conversation, or shows the source checkout's catalog and asks what to create or change.

The bundled [source resolver](scripts/resolve-source-repo.ps1) checks an explicit checkout
("in <checkout path>"), the working project, the known Windows checkout `C:\repos\skillvault`, then
the source cache. It requires a SkillVault layout at the exact Git root and a verified
`wzlwit/skillvault` origin. An invalid explicit/preferred source blocks edits; it is not silently
replaced. Source root, catalog, and skill destination are displayed before authoring. Uncommitted
work is preserved.

When no source is found, choose an explicit checkout or approve cloning into
`~/.copilot/skillvault-src` or a remote pull request. No source files are written into an unrelated
working project. Resolution itself is read-only and uses PowerShell 5.1+ or PowerShell 7 and Git,
with no network calls.

The resolver reuses the sibling `skillvault-install` bundle's verifier in Upsert mode. Keep that
declared dependency installed beside this skill; upsert's existing source selection is unchanged.

Examples:

```text
/skillvault-author
/skillvault-author code-review
/skillvault-author https://github.com/twpayne/chezmoi
/skillvault-author schedule-helper in C:\repos\skillvault
/skillvault-author https://github.com/twpayne/chezmoi publish
/skillvault-author remove old-skill
```

Publishing is separate: this skill does not commit, push, or open a PR unless explicitly asked.
