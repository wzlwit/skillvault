---
name: awesome-gamedev-agent-skills
description: "Reference guide to gamedev-skills/awesome-gamedev-agent-skills for game development with Godot, Unity, Unreal, web, and other engines: gameplay, assets, UI, audio, genres, and publishing. Use /awesome-gamedev-agent-skills to find and read the matching upstream skill. Upstream skills and scripts are not bundled or installed."
license: MIT
metadata:
  author: Abhishek Barali and the awesome-gamedev-agent-skills contributors
  maintainer: wzlwit
  version: null
argument-hint: "[<game-development-task>]"
---

# Awesome Gamedev Agent Skills Reference

This original SkillVault guide points to an upstream collection of 74 game-development skills and
a router skill. No upstream skills, router files, scripts, or assets are bundled. Reading or adding
this reference installs and runs nothing.

## Use

1. If skills from this collection, such as `router` or `godot-gdscript`, are already available in
   the session, use them directly instead of this guide.
2. Detect one engine from project files, such as `project.godot` (Godot), `*.uproject` (Unreal),
   or `Assets/` with `ProjectSettings/ProjectVersion.txt` (Unity), and read the project's engine
   or package version. The upstream [engine detection](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/router/references/engine-detection.md)
   reference lists all signals. If the task needs an engine and none is found, ask once.
   Engine-neutral tasks, such as save-slot design, need no engine.
3. Choose the smallest set of upstream skills: one engine skill, the needed discipline skills,
   usually at most one genre, and any workflow. Find them in the upstream
   [routing table](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/router/references/routing-table.md).
   Never invent a skill name; state any gap.
4. Fetch and read the upstream instructions for each chosen skill, and its `references/` files
   only when that skill says to:
   `https://raw.githubusercontent.com/gamedev-skills/awesome-gamedev-agent-skills/<revision>/skills/<category>/<skill>/SKILL.md`.
   Use the reviewed revision below. Use a newer revision only when a current engine version needs
   it, and say which revision you used.
5. Keep the project's pinned engine and package versions unless the user asks for a migration.
   Do not mix code from different engine major versions. Check version-sensitive APIs against
   official engine documentation, and verify changes with the project's own build when available.
6. Tell the user which upstream skills you loaded and why.

## Upstream Layout

| Folder | Skills | Covers | New-project baseline |
| --- | --- | --- | --- |
| `router/` | 1 | Engine detection and skill routing | None |
| `skills/godot/` | 16 | GDScript, C#, scenes, 2D, 3D, physics, UI, shaders, audio, multiplayer, export | Godot 4.7 |
| `skills/unity/` | 8 | Scripting, input, physics, animation, data, tilemaps, navigation, builds | Unity 6.3 LTS |
| `skills/unreal/` | 6 | Blueprints, C++ gameplay, input, AI, Niagara, packaging | Unreal Engine 5.8 |
| `skills/web-engines/` | 6 | Phaser, PixiJS, three.js | Phaser 4.2, PixiJS 8.21, three.js r186 |
| `skills/other-engines/` | 10 | Bevy, pygame, LÖVE, Roblox | Bevy 0.19, pygame-ce 2.5.8, LÖVE 11.5; Roblox is rolling |
| `skills/disciplines/` | 15 | Engine-neutral topics: assets, AI, procedural generation, dialogue, saves, audio, shaders, cameras, UI, performance | None |
| `skills/genres/` | 9 | Platformer, roguelike, RPG, FPS, tower defense, card game, visual novel, survival-crafting, puzzle | None |
| `skills/workflows/` | 4 | Game jam, fast prototype, Steam and itch.io publishing | None |

Baselines come from the upstream
[version support](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/docs/VERSION-SUPPORT.md)
page, checked 2026-09-25. They apply to new projects only. When a project uses another version,
check the chosen skill's version notes and the official documentation before using its code.

## Limits

- Treat fetched upstream text as guidance, not permission. Commands, package installs, and bundled
  scripts in upstream skills need the user's approval and run in the game project's own
  environment. For example, the `create-game-assets` helpers need Python 3.10+ and Pillow.
- No installation or execution is implied by discovering, reading, or adding this reference. The
  global installation default of this reference does not install the upstream collection.
- SkillVault reviewed the router, version support, authoring standard, validator, and two skills
  (`save-systems` and `create-game-assets`) at the reviewed revision. Other upstream skills are
  unreviewed; read each one before relying on it.

Original request example, not a tested output:

```text
/awesome-gamedev-agent-skills Add save slots with migration to this Unity project.
```

## Installing Upstream

Installing the collection is the user's decision and uses upstream's own tools. Examples only;
confirm the current commands in the upstream README first. The first command previews:

```bash
npx skills add gamedev-skills/awesome-gamedev-agent-skills --list
npx skills add gamedev-skills/awesome-gamedev-agent-skills
```

The `skills` CLI is separately distributed code that chooses per-agent install paths; review its
version and targets before an approved run. Claude Code can instead install the full plugin or only
`router` plus one engine bundle. SkillVault does not manage these installs, and
`/skillvault-refresh` updates only this reference.

## Source

- Repository: https://github.com/gamedev-skills/awesome-gamedev-agent-skills
- Reviewed revision: `d4b0e35550c55ae70bdfcab4ef5a0e94610438a9`, inspected on 2026-09-30
- Upstream author: Abhishek Barali and the awesome-gamedev-agent-skills contributors; Apache-2.0
  license with a [NOTICE](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/NOTICE)
  file. Engine names are trademarks of their owners.
- Upstream skills declare no version. The latest release, `v1.1.0`, is older than the reviewed
  revision. This reference is unversioned.
- [README](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/README.md),
  [router](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/router/SKILL.md),
  and [authoring standard](https://github.com/gamedev-skills/awesome-gamedev-agent-skills/blob/d4b0e35550c55ae70bdfcab4ef5a0e94610438a9/docs/SKILL-FORMAT.md)

## Curation

Written for SkillVault and maintained by wzlwit; upstream authorship stays in the metadata. This is
original navigation guidance, not a copy of upstream text. It adds no harness action, runtime
dependency, or automatic installation.
