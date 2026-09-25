# Handoff

A lightweight, explicitly invoked [continuation-note skill](./SKILL.md), adapted from
[Matt Pocock's handoff](https://github.com/mattpocock/skills/blob/main/skills/productivity/handoff/SKILL.md).
It keeps artifact links, blockers, process uncertainty, and the next step together without adding
another task store or replacing existing stop/recovery controls.

```text
/handoff
/handoff continue investigating the failing test
/handoff prepare for the next reviewer --output docs/handoff-review.md
```

Defaults to global availability, with explicit project installation supported. Invoking
`/handoff` writes a note using the explicit destination
or established project handoff/documentation location; standalone work can use OS temporary storage.
It works without harness initialization. When a harness is present, it reuses context and evidence;
`/harness-policy fallback` still owns actual execution controls. Suggested next actions are not automatic resume.

The bundle includes no scripts, hooks, or upstream plugin setup. Installing it creates no handoff
note and changes no runtime state. Original author: Matt Pocock; curator: wzlwit; [license: MIT](./LICENSE).
Version is explicitly `null` because this adaptation does not track an upstream release.