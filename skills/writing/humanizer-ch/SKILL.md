---
name: humanizer-ch
description: "Reference guide to zjqc/humanizer-ch for Chinese critical essays and theoretical commentary. Use /humanizer-ch to locate upstream guidance; overlaps with humanizer on prose editing. Upstream rules and scripts are not bundled."
metadata:
  author: null
  maintainer: wzlwit
  version: null
argument-hint: "[<text-or-file>] [<editing-goal>]"
---

# Humanizer CH Reference

This original SkillVault reference points to a specialized Chinese critical-essay editing guide.
The upstream focuses on argument density, authorial judgment, and academic register in essays,
art reviews, exhibition writing, and theoretical commentary. It is not a general Chinese-language
replacement for `humanizer` or the technical-document workflow in `harness-doc`.

## Use and Limits

- No upstream rewriting rules, examples, scripts, or Codex UI files are bundled. Installing this
  reference runs no upstream command and does not rewrite an open file.
- Before an explicitly requested rewrite, fetch and read the upstream instructions for the
  selected source/revision. If unavailable, report the limitation; do not substitute a summary
  or a different Chinese Humanizer variant and claim the upstream workflow ran.
- Choose by the requested genre and goal, not language alone. Preserve the user's language,
  supported claims, qualifications, and authorial stance. Missing evidence is not permission
  to invent details, quotations, or citations for a more vivid result.
- For file edits, retain the selected scope and applicable project rules, including protected
  headings, code, data, frontmatter, and link targets. Do not inject diagnostic commentary into
  a final-prose-only deliverable. Confirm before expanding the requested edit or publishing.
- Unknown upstream licensing does not authorize copying or redistributing its material. This
  reference grants no rights to the upstream bundle and does not install its maintenance tools.

Original invocation example for the referenced genre:

```text
/humanizer-ch 请润色这段中文艺术评论，保留论点、材料和作者立场，不要补充未提供的事实。
```

This is a usage example, not an upstream example or a validated Chinese editing result.

## Source

- Repository: https://github.com/zjqc/humanizer-ch
- Instructions: https://github.com/zjqc/humanizer-ch/blob/main/SKILL.md
- Reviewed revision: `ae195e61e90b97d32aca683382c5732608b17fb1`
- Publisher: `zjqc`; original authorship, release version, and license are not declared in the
  inspected source. Preserve these unknowns rather than infer them from the repository name.

## Curation

Written for SkillVault and maintained by wzlwit. This entry contains original navigation and
scope guidance, not an import, translation, or implementation of the upstream editing procedure.
`humanizer` references the general prose editor; this entry references the separate Chinese
critical-essay specialization. Neither reference certifies writing quality or human authorship.