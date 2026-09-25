import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseJson, parseSkill, resolveInside, validateRepository, validateRuntimeInterfaces } from './validate-skill-files.mjs';

const validSkill = '---\nname: fixture\ndescription: A valid fixture\nargument-hint: "[value]"\nmetadata:\n  version: "1.0.0"\n---\n# Fixture\n';

const harnessProcedures = {
  context: 'harness/references/context.md',
  decide: 'harness-decision/references/workflow.md',
  dev: 'harness-dev/references/workflow.md',
  fallback: 'harness-policy/references/fallback.md',
  init: 'harness/references/init.md',
  loc: 'harness/references/loc.md',
  monitor: 'harness-monitor/references/workflow.md',
  ref: 'harness-link/references/workflow.md',
  'report-create': 'harness-report/references/workflow.md',
  restrict: 'harness-policy/references/limits.md',
  review: 'harness-review/references/workflow.md',
  root: 'harness/references/loc.md',
  task: 'harness-task/references/workflow.md',
  test: 'harness-test/references/workflow.md',
  timer: 'harness-timer/references/project.md',
};

test('valid headers and explicit null metadata remain supported', () => {
  assert.equal(parseSkill(validSkill, 'fixture', { version: '1.0.0' }).name, 'fixture');
  assert.equal(parseSkill(validSkill.replace('"1.0.0"', 'null'), 'fixture', { version: null }).metadata.version, null);
  assert.equal(parseJson('{"version":null}', 'fixture.json').version, null);
});

test('malformed YAML, duplicate keys, and mismatched names or versions fail', () => {
  assert.throws(() => parseSkill(validSkill.replace('  version: "1.0.0"', '  version: "1.0.0"\n   argument-hint: value'), 'fixture'));
  assert.throws(() => parseSkill(validSkill.replace('name: fixture', 'name: fixture\nname: duplicate'), 'fixture'));
  assert.throws(() => parseSkill(validSkill, 'other'));
  assert.throws(() => parseSkill(validSkill, 'fixture', { version: '2.0.0' }));
  assert.throws(() => parseJson('{"version":null,"version":"1.0.0"}', 'fixture.json'));
  assert.throws(() => parseJson('{invalid}', 'fixture.json'));
});

test('root containment uses path boundaries', () => {
  const root = path.resolve('fixtures');
  assert.equal(resolveInside(root, 'skill/SKILL.md'), path.join(root, 'skill/SKILL.md'));
  assert.throws(() => resolveInside(root, '../fixtures-other/SKILL.md'));
});

test('runtime interface declarations are explicit independently versioned contracts', () => {
  validateRuntimeInterfaces({ name: 'legacy', version: '1.0.0' });
  validateRuntimeInterfaces({ name: 'provider', version: '9.0.0', runtimeInterfaces: { receipt: 1 } });
  validateRuntimeInterfaces({ name: 'consumer', dependencies: ['provider'], requiredInterfaces: { provider: { receipt: 1 } } });
  for (const version of [null, true, '1', 0, -1, 1.5]) {
    assert.throws(() => validateRuntimeInterfaces({ name: 'provider', runtimeInterfaces: { receipt: version } }));
  }
  for (const interfaces of [null, [], 'receipt']) {
    assert.throws(() => validateRuntimeInterfaces({ name: 'provider', runtimeInterfaces: interfaces }));
  }
  assert.throws(() => validateRuntimeInterfaces({ name: 'consumer', dependencies: [], requiredInterfaces: { provider: { receipt: 1 } } }));
});

test('catalog installation defaults are supported and shared helpers stay colocated', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const manifests = new Map(catalog.map(entry => [entry.name, parseJson(fs.readFileSync(path.join(root, entry.path, 'skill.json'), 'utf8'), `${entry.name}/skill.json`)]));
  for (const [name, manifest] of manifests) {
    assert.ok(['global', 'project', 'session'].includes(manifest.install.defaultScope), `Missing declared scope for ${name}`);
    assert.equal(manifest.install[manifest.install.defaultScope], true, `Unsupported default scope for ${name}`);
  }
  for (const [caller, helper] of [
    ['harness-timer', 'harness'],
    ['pr-review', 'harness'],
    ['skillvault-authoring', 'skillvault-installation'],
    ['skillvault-refresh', 'skillvault-installation'],
  ]) {
    assert.equal(manifests.get(caller).install.defaultScope, manifests.get(helper).install.defaultScope, `${caller} requires sibling ${helper}`);
  }
});

test('Power BI modeling preserves scope and grain-aware validation cases', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'powerbi-modeling');
  assert.equal(entry.path, 'skills/data/powerbi-modeling');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'powerbi-modeling/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.version, null);
  assert.equal(manifest.version, null);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.equal(manifest.author, null);
  assert.equal(manifest.upstream.license, 'MIT');
  assert.match(manifest.upstream.revision, /^[a-f0-9]{40}$/);
  assert.equal(skill.description, manifest.description);
  assert.equal(entry.description, manifest.description);
  assert.ok(skill.description.includes('kpi-dashboard'));
  const counterpart = catalog.find(candidate => candidate.name === 'kpi-dashboard');
  const counterpartManifest = parseJson(fs.readFileSync(path.join(root, counterpart.path, 'skill.json'), 'utf8'), 'kpi-dashboard/skill.json');
  const counterpartSkill = parseSkill(fs.readFileSync(path.join(root, counterpart.path, 'SKILL.md'), 'utf8'), counterpart.name, counterpartManifest);
  for (const description of [counterpart.description, counterpartManifest.description, counterpartSkill.description]) {
    assert.ok(description.includes('powerbi-modeling'), 'Declare the reciprocal metric/grain overlap');
  }
  assert.match(content, /Design or explain[\s\S]*No live connection is required/);
  assert.match(content, /Do not select the first open Desktop model/);
  assert.match(content, /Designing, explaining, reviewing, and installing this guide do not authorize model writes/);
  const validation = fs.readFileSync(path.join(directory, 'references/validation.md'), 'utf8');
  const fixture = parseJson(/```json\r?\n([\s\S]*?)\r?\n```/.exec(validation)[1], 'model validation case');
  const orders = new Set(fixture.rows.map(row => row.OrderId));
  const total = fixture.rows.reduce((sum, row) => sum + row.Amount, 0);
  assert.equal(fixture.rows.length, fixture.expected.lineCount);
  assert.equal(orders.size, fixture.expected.orderCount);
  assert.notEqual(orders.size, fixture.rows.length);
  assert.equal(total, fixture.expected.totalAmount);
  assert.equal(total / orders.size, fixture.expected.averageOrderValue);
  const filters = fixture.filterCase;
  assert.equal(fixture.rows.filter(row => row.Amount <= filters.existingMaximum && row.Amount > filters.newMinimumExclusive).length, filters.intersectionRows);
  assert.equal(fixture.rows.filter(row => row.Amount > filters.newMinimumExclusive).length, filters.replacementRows);
  for (const security of fixture.securityCases) {
    const regions = new Set(fixture.identityMapping.filter(mapping => security.identity != null && mapping.identity === security.identity).map(mapping => mapping.region));
    assert.equal(fixture.rows.filter(row => regions.has(row.RegionKey)).length, security.expectedRows);
  }
});

test('harness topics use canonical names and conversational hn shortcuts', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const topics = ['harness', ...['policy', 'decision', 'dev', 'review', 'task', 'link', 'test', 'monitor', 'report', 'timer'].map(suffix => `harness-${suffix}`)];
  assert.deepEqual(catalog.filter(entry => entry.name === 'harness' || entry.name.startsWith('harness-')).map(entry => entry.name).sort(), topics.slice().sort());
  for (const name of topics) {
    const entries = catalog.filter(entry => entry.name === name);
    assert.equal(entries.length, 1, `Expected exactly one ${name} catalog entry`);
    assert.equal(entries[0].path, `skills/planning/${name}`);
    const directory = path.join(root, entries[0].path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    assert.equal(manifest.name, name);
    assert.equal(manifest.source.path, entries[0].path);
    assert.equal(manifest.install.defaultScope, 'global');
    assert.equal(manifest.install.project, true);
    const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const skill = parseSkill(instructions, name, manifest);
    assert.match(skill.description, new RegExp(`/${name}(?![\\w-])`));
    const shortcut = name === 'harness' ? 'hn' : name.replace('harness-', 'hn-');
    assert.match(skill.description, new RegExp(`/${shortcut}(?![\\w-])`));
    assert.match(instructions, /shorthand for the same topic and subcommands, not a separate skill or folder/);
    assert.notEqual(skill['user-invocable'], false);
    assert.match(skill['argument-hint'], /^\[list(?:\||\])/);
    assert.equal(manifest.inputs.find(input => input.name === 'action').default, 'list');
    assert.equal((manifest.dependencies ?? []).some(dependency => dependency.startsWith('hn-')), false);
  }
  for (const entry of catalog) {
    assert.doesNotMatch(entry.name, /^(hn-|sv-)/, `Register only the canonical topic: ${entry.name}`);
  }
  for (const [category, legacyPrefix] of [['planning', 'hn-'], ['core', 'sv-']]) {
    const legacyDirectories = fs.readdirSync(path.join(root, 'skills', category), { withFileTypes: true })
      .filter(entry => entry.isDirectory() && entry.name.startsWith(legacyPrefix))
      .map(entry => entry.name);
    assert.deepEqual(legacyDirectories, [], `Remove obsolete source folders from ${category}`);
  }
  for (const retired of ['harness-context', 'harness-decide', 'harness-fallback', 'harness-init', 'harness-loc', 'harness-management', 'harness-ref', 'harness-report-create', 'harness-restrict', 'harness-root', 'hn', 'hn-decision', 'hn-management', 'hn-timer']) {
    assert.equal(fs.existsSync(path.join(root, 'skills/planning', retired)), false, `Do not retain a duplicate ${retired} source bundle`);
  }
});

test('SkillVault topics register full names and keep sv as conversational shortcuts', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const topics = ['authoring', 'discovery', 'installation', 'refresh'].map(suffix => `skillvault-${suffix}`);
  assert.deepEqual(catalog.filter(entry => entry.name.startsWith('skillvault-')).map(entry => entry.name).sort(), topics);
  for (const name of topics) {
    const entry = catalog.find(candidate => candidate.name === name);
    assert.equal(entry.path, `skills/core/${name}`);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const skill = parseSkill(fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8'), name, manifest);
    const shortcut = name.replace('skillvault-', 'sv-');
    assert.equal(manifest.name, name);
    assert.equal(manifest.source.path, entry.path);
    assert.notEqual(skill['user-invocable'], false);
    assert.match(skill.description, new RegExp(`/${name}(?![\\w-])`));
    assert.match(skill.description, new RegExp(`/${shortcut}(?![\\w-])`));
    assert.equal(fs.existsSync(path.join(root, 'skills/core', shortcut)), false);
    assert.equal((manifest.dependencies ?? []).some(dependency => dependency.startsWith('sv-')), false);
  }
  assert.equal(fs.existsSync(path.join(root, 'skills/core/skillvault-source')), false);
  const authoring = fs.readFileSync(path.join(root, 'skills/core/skillvault-authoring/SKILL.md'), 'utf8');
  for (const alias of ['/skillvault-source', '/sv-source']) assert.ok(authoring.includes(alias), `Preserve ${alias} compatibility`);
});

test('harness initialization reuses selected root without another location prompt', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.init), 'utf8');
  const selection = guide.indexOf('## Reuse the Selected Root');
  assert.ok(selection > 0 && selection < guide.indexOf('## Workflow'));
  assert.match(guide, /including the displayed `\.\/` fallback/);
  assert.match(guide, /Do not ask for location confirmation again/);
  assert.match(guide, /If no Root has been selected[\s\S]*\/harness root \.\//);
  assert.match(guide, /Supply `-ConfirmLocation` automatically/);
  assert.match(guide, /-Action Init -ConfirmLocation/);
  assert.match(guide, /\/harness root/);
  assert.doesNotMatch(guide, /Bare reconnects require the same choice|fallback is not initialization confirmation/);
});

test('harness root selects a parent and preserves legacy board boundaries', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.root), 'utf8');
  const location = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.loc), 'utf8');
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness/references/runtime.md'), 'utf8');
  assert.equal(harnessProcedures.root, harnessProcedures.loc);
  assert.match(guide, /always prompt\s+to confirm the location/i);
  assert.match(guide, /If there is no answer[\s\S]*displayed `\.\/` for session selection/);
  assert.match(guide, /subsequent harness actions, including\s+`\/harness init`[\s\S]*without another location confirmation/);
  assert.match(runtime, /## Root Inheritance/);
  assert.match(runtime, /Every harness action reuses the selected Root/);
  assert.match(runtime, /location selection, not blanket permission/);
  assert.match(guide, /-Action Root/);
  assert.match(location, /`\/harness root <path>` selects the parent/);
  assert.match(location, /`\/hn root` is shorthand for `\/harness root`/);
  assert.match(location, /`\/harness loc` and `\/hn loc` remain aliases/);
  assert.match(location, /`\.harness_sv\/` workspace/);
  assert.match(location, /Newly initialized controllers[\s\S]*`\.harness_sv\/`/);
  assert.match(runtime, /## Artifact Storage/);
  for (const folder of ['docs/plans', 'docs/handoffs', 'definitions', 'artifacts', 'history']) {
    assert.ok(runtime.includes(`.harness_sv/${folder}/`), `Missing default harness output location: ${folder}`);
  }
  assert.match(runtime, /explicit user destination overrides/);
  assert.match(runtime, /Pass the resolved output path to any delegated/);
  assert.match(location, /without another confirmation prompt/);
  const relocation = location.split('## Explicit Relocation')[1]?.split('\n## ')[0];
  assert.ok(relocation, 'Root selection must own its move confirmation');
  assert.match(relocation, /`\/harness root <new-parent>`[\s\S]*previously selected harness was initialized[\s\S]*target differs/);
  const choices = relocation.split('\n').filter(line => /^\| (Yes:|No:)/.test(line));
  assert.equal(choices.length, 2, 'The prompt decides only whether existing data moves');
  assert.match(choices[0], /Yes: Move \(default\)[\s\S]*Preview[\s\S]*apply the requested relocation/);
  assert.match(choices[1], /No: Do Not Move[\s\S]*Leave the old controller, records, and schedules in place/);
  assert.deepEqual(choices.map(line => line.split('|')[3].trim()), ['New root', 'New root']);
  assert.match(relocation, /No answer[\s\S]*uses Move after\s+displaying the prompt and default\. Preview and apply/);
  assert.match(relocation, /explicit answer or applicable user instruction takes precedence over the default/);
  assert.match(relocation, /explicit No,\s+cancel, or instruction not to move[\s\S]*keeps the new Root selected/);
  assert.match(relocation, /ambiguous substantive answer needs clarification/);
  assert.match(relocation, /not that the user answered Yes/);
  assert.match(relocation, /Scheduled ticks cannot initiate this root-change workflow/);
  assert.match(location, /`\/hn-root <path>`[\s\S]*`\/hn root <path>` do not add a second location prompt/);
  assert.match(relocation, /first-selection `\.\/` fallback does not apply/);
  assert.match(relocation, /blocked or failed move is reported separately[\s\S]*new Root remains selected/);
  assert.match(relocation, /-ProjectPath <previous-root> -Action Root -Move -DestinationPath <new-parent> -Apply/);
  assert.match(location, /source\s+and target are the same[\s\S]*without a move prompt/);
  assert.match(location, /select the valid new root\s+before asking about moving data/);
  assert.match(location, /previous harness is not initialized[\s\S]*without another confirmation prompt/);
  assert.match(location, /invalid target leaves the current Root unchanged/);
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'skills/planning/harness/skill.json'), 'utf8'));
  const entrypoint = fs.readFileSync(path.join(root, 'skills/planning/harness/SKILL.md'), 'utf8');
  assert.equal(manifest.inputs.some(input => input.name === 'move'), false, 'Move confirmation replaces a public move flag');
  assert.doesNotMatch(manifest.description + manifest.examples.join(' '), /--move/);
  assert.match(entrypoint, /\| `root \[<path>\]` \|/);
  assert.match(location, /-BoardPath <path>/);
  assert.doesNotMatch(guide, /Never pass `-ConfirmLocation`[\s\S]*unanswered root prompt/);
  for (const suffix of ['context', 'decide', 'report-create']) {
    const standalone = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(standalone, /Reuse the selected Root without another location prompt/);
    assert.match(standalone, /If no Root or explicit target exists, use\s+`\/harness root \.\/` once/);
    assert.doesNotMatch(standalone, /Identify the target project from the request or workspace/);
  }
});

test('harness script permissions precede execution and agent fallback preserves boundaries', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness/references/runtime.md'), 'utf8');
  const procedure = runtime.split('## Script Permissions and Agent Fallback')[1]?.split('\n## ')[0];
  assert.ok(procedure, 'Missing shared permission/fallback procedure');
  assert.match(procedure, /Reuse existing approvals/);
  assert.match(procedure, /permission\s+request before execution/);
  assert.match(procedure, /not permission to repeat an explicit denial/);
  assert.match(procedure, /exclusive workspace ownership/);
  assert.match(procedure, /do not mark the task Completed/);
  assert.match(procedure, /Unattended timer\s+ticks never/);
  const development = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.dev), 'utf8');
  const preflight = development.indexOf('## Before Scripts');
  assert.ok(preflight > 0 && preflight < development.indexOf('-Action Dev'));
  assert.ok(development.indexOf('Resolve runner allowances') < development.indexOf('-Action Dev'));
  assert.match(development, /attended agent fallback/);
  for (const suffix of ['init', 'review', 'test', 'restrict', 'fallback', 'timer']) {
    const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(guide, /Script Permissions and Agent\s+Fallback/, `Missing preflight guidance: harness-${suffix}`);
  }
  const scheduler = fs.readFileSync(path.join(root, 'skills/planning/harness-timer/references/scheduler.md'), 'utf8');
  const capabilities = scheduler.split('### Conditional Capabilities')[1]?.split('\n## ')[0];
  assert.ok(capabilities, 'Maintenance must distinguish capability permission from activation');
  const capabilitiesTable = capabilities.split('\n').filter(line => /^\| (Machine wake|AI assistance) \|/.test(line));
  assert.equal(capabilitiesTable.length, 2);
  assert.match(capabilitiesTable[0], /approved window[\s\S]*No known work means no wake request/);
  assert.match(capabilitiesTable[1], /deterministic checks cannot provide[\s\S]*permissions, and budgets/);
  assert.match(capabilities, /permission, not automatic activation/);
  assert.match(capabilities, /cannot expand cleanup candidates, authorize\s+deletion, clear safety pauses/);
  assert.match(capabilities, /permissions alone reconfigure no live task and launch no AI process/);
});

test('harness missing allowances inherit without invented limits', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness/references/runtime.md'), 'utf8');
  const inheritance = runtime.split('## Runner Inheritance')[1]?.split('\n## ')[0];
  assert.ok(inheritance);
  assert.match(inheritance, /Missing or null allowances inherit/);
  assert.match(inheritance, /maximum verified available profile\/effort\/context/);
  assert.match(inheritance, /-RunnerContextPath/);
  assert.match(inheritance, /does not rewrite project settings/);
  assert.match(inheritance, /Blank strings and empty allowance lists add no local restriction/);
  assert.match(inheritance, /`None`, and `Max` use inheritance/);
  const restrictions = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.restrict), 'utf8');
  assert.match(restrictions, /No default restriction is added/);
  assert.match(restrictions, /"allowedModels": "None"/);
  assert.match(restrictions, /"maxAgentCredits": "Max"/);
  for (const suffix of ['dev', 'review', 'restrict', 'timer']) {
    const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(guide, /Runner\s+Inheritance/);
    assert.doesNotMatch(guide, /Missing runtime settings require setup|unresolved execution settings before creating/);
  }
});

test('harness confirms reuse or new without sharing reviewer conclusions or bypassing locks', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness/references/runtime.md'), 'utf8');
  const selection = runtime.split('## Reuse or New')[1]?.split('\n## ')[0];
  assert.ok(selection, 'Missing shared instance-selection procedure');
  assert.match(selection, /Reuse \(singleton\) or New\?/);
  assert.match(selection, /choice is unanswered[\s\S]*create no additional one/);
  assert.match(selection, /fresh reviewer context/);
  assert.match(selection, /script remains serialized/);
  assert.match(selection, /PR-review timer remains a singleton/);
  for (const suffix of ['dev', 'review', 'timer']) {
    const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(guide, /Reuse or New/);
    assert.match(guide, /Reuse \(singleton\) or New\?/);
  }
  const timer = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.timer), 'utf8');
  assert.match(timer, /-InstanceMode New -InstanceName/);
  assert.match(timer, /NeedsInstanceChoice/);
  assert.match(timer, /same purpose|same E2E|same topic/);
});

test('handoff preserves explicit invocation, global default, and upstream attribution', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/planning/handoff');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'handoff/skill.json');
  const skill = parseSkill(fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8'), 'handoff', manifest);
  assert.equal(skill['disable-model-invocation'], true);
  assert.notEqual(skill['user-invocable'], false);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.equal(manifest.install.project, true);
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.equal(manifest.version, null);
  assert.equal(manifest.author, 'Matt Pocock');
  assert.equal(skill.metadata.author, manifest.author);
  assert.equal(manifest.upstream.path, 'skills/productivity/handoff');
  assert.equal(manifest.license, 'MIT');
  assert.match(fs.readFileSync(path.join(directory, 'LICENSE'), 'utf8'), /Copyright \(c\) 2026 Matt Pocock/);
});

test('handoff follow-ups stay optional at selected transfer points', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const [name, procedure] of [
    ['harness', 'references/context.md'],
    ['harness-decision', 'references/workflow.md'],
    ['harness-dev', 'references/workflow.md'],
    ['harness-policy', 'references/fallback.md'],
    ['harness-report', 'references/workflow.md'],
    ['skillvault-discovery', 'references/search.md'],
  ]) {
    const entry = catalog.find(candidate => candidate.name === name);
    assert.ok(entry, `Missing integration skill: ${name}`);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const instructions = fs.readFileSync(path.join(directory, procedure), 'utf8');
    assert.match(instructions, /\/handoff(?![\w-])/, `Missing handoff reference: ${name}`);
    assert.equal((manifest.dependencies ?? []).includes('handoff'), false, `Handoff must remain optional for ${name}`);
  }
});

test('report authoring advertises Jarvis and query routes with an optional specialist', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const [name, counterpart] of [
    ['harness-report', 'jarvis-metrics'],
    ['jarvis-metrics', 'harness-report'],
  ]) {
    const entry = catalog.find(candidate => candidate.name === name);
    assert.ok(entry, `Missing reporting skill: ${name}`);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const skill = parseSkill(fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8'), name, manifest);
    for (const description of [entry.description, manifest.description, skill.description]) {
      assert.ok(description.includes(counterpart), `Missing reporting overlap: ${name}`);
    }
    if (name === 'harness-report') {
      const workflow = fs.readFileSync(path.join(directory, 'references/workflow.md'), 'utf8');
      for (const route of ['powerbi', 'grafana', 'jarvis', 'web', 'query']) {
        assert.match(workflow, new RegExp(`\\b${route}\\b`));
      }
      assert.equal((manifest.dependencies ?? []).includes('jarvis-metrics'), false);
      const routes = fs.readFileSync(path.join(directory, 'references/report-routes.md'), 'utf8');
      assert.match(routes, /^## Jarvis\r?$/m);
      assert.match(routes, /`jarvis-metrics`/);
    }
  }
});

test('PR commands share one global-default runtime without recursive harness routing', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const name of ['pr-review', 'pr-watch', 'harness-timer']) {
    const entries = catalog.filter(entry => entry.name === name);
    assert.equal(entries.length, 1);
    assert.equal(entries[0].path, `skills/${name === 'harness-timer' ? 'planning' : 'github'}/${name}`);
    const directory = path.join(root, entries[0].path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const guide = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const skill = parseSkill(guide, name, manifest);
    assert.equal(manifest.install.defaultScope, 'global');
    assert.match(skill.description, new RegExp(`/${name}(?![\\w-])`));
    assert.match(guide, /user-wide/);
    assert.equal(manifest.dependencies.includes('harness-review'), false);
    assert.ok(manifest.dependencies.includes(name === 'pr-review' ? 'harness' : 'pr-review'));
  }
  for (const [name, counterpart] of [['harness-review', 'pr-review'], ['differential-review', 'pr-review'], ['schedule-manager', 'harness-timer']]) {
    const entry = catalog.find(candidate => candidate.name === name);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const skill = parseSkill(fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8'), name, manifest);
    for (const description of [entry.description, manifest.description, skill.description]) assert.ok(description.includes(counterpart));
  }
});

test('topic map covers canonical skills and rules apply stays separate from authoring', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const plan = fs.readFileSync(path.join(root, 'docs/plans/2026-09-16-topic-skill-refactor.md'), 'utf8');
  const targets = [...plan.matchAll(/^\| [a-z][a-z0-9-]* \| ([a-z][a-z0-9-]*)/gm)].map(match => match[1]);
  assert.deepEqual([...new Set(targets)].sort(), catalog.map(entry => entry.name).sort());
  assert.match(plan, /```mermaid\r?\nflowchart LR/);
  assert.match(plan, /Harness topics register as `\/harness` and `\/harness-\*`/);
  assert.match(plan, /`\/hn-\*` is only conversational shorthand/);
  assert.match(plan, /## Project Storage[\s\S]*<root>\/\.harness_sv\//);
  const folderTree = plan.match(/## Folder Layout[\s\S]*?```text\r?\n([\s\S]*?)```/);
  assert.ok(folderTree, 'Show the actual source folder layout separately from the command diagram');
  const listedFolders = [];
  let category;
  for (const line of folderTree[1].split(/\r?\n/)) {
    const parent = line.match(/^[|`]-- ([a-z-]+)\/$/);
    if (parent) category = parent[1];
    const child = line.match(/^(?:\| +| +)[|`]-- ([a-z-]+)\/$/);
    if (child) listedFolders.push(`skills/${category}/${child[1]}`);
  }
  assert.deepEqual(listedFolders.sort(), catalog.filter(entry => /^skills\/(core|github|planning)\//.test(entry.path)).map(entry => entry.path).sort());
  const rulesRoot = path.join(root, 'skills/core/rules');
  const rules = fs.readFileSync(path.join(rulesRoot, 'SKILL.md'), 'utf8');
  const core = fs.readFileSync(path.join(rulesRoot, 'references/core.md'), 'utf8');
  const management = fs.readFileSync(path.join(rulesRoot, 'references/manage.md'), 'utf8');
  assert.equal([...core.matchAll(/^\d\. \*\*/gm)].length, 4);
  assert.match(rules, /apply[\s\S]*without editing files/);
  assert.match(management, /Wait for explicit confirmation/);
  const runner = fs.readFileSync(path.join(root, 'skills/planning/harness/scripts/harness-runner.ps1'), 'utf8');
  assert.match(runner, /rules\/references\/core\.md/);
  assert.doesNotMatch(runner, /rules\/references\/manage\.md/);
  const source = fs.readFileSync(path.join(root, 'skills/core/skillvault-authoring/SKILL.md'), 'utf8');
  assert.match(source, /SkillVault repository/);
  assert.match(source, /not an application's\s+source tree/);
  assert.match(source, /installation target/);
});

test('multi-action topics default to list and keep aliases out of primary menus', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const entry of catalog.filter(entry => /^(harness(?:-|$)|skillvault-|pr-review$|pr-watch$|rules$|schedule-manager$)/.test(entry.name))) {
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${entry.name}/skill.json`);
    const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const guide = parseSkill(instructions, entry.name, manifest);
    const action = manifest.inputs.find(input => input.name === 'action');
    assert.equal(action.default, 'list', entry.name);
    assert.deepEqual(action.enum, guide['argument-hint'].match(/^\[([^\]]+)\]/)[1].split('|'), entry.name);
    assert.equal(action.enum.length, new Set(action.enum).size, entry.name);
    assert.match(instructions, /Action matching applies only to the explicit action token/, entry.name);
    assert.match(instructions, /Exact canonical actions and documented\s+aliases take precedence/, entry.name);
    assert.match(instructions, /Otherwise, accept exactly 3 or 4 leading letters only when they match one\s+canonical action in this topic/, entry.name);
    assert.match(instructions, /Multiple matches: show choices and ask; no match: show help/, entry.name);
    assert.match(instructions, /Ambiguous or unknown tokens execute nothing/, entry.name);
    assert.match(instructions, /Do not prefix-match aliases, skill names, targets,\s+paths, options, or other arguments/, entry.name);
    assert.match(instructions, /Preserve existing case handling and natural-language routing/, entry.name);
    assert.match(instructions, /existing procedure with arguments, permissions, and confirmations unchanged/, entry.name);
    assert.match(instructions, /no extra confirmation is required merely for abbreviation/, entry.name);
    assert.match(instructions, /conversational routing, not script argument parsing/, entry.name);
    for (const alias of ['help', 'status', 'show', 'now', 'next']) assert.ok(!action.enum.includes(alias), `${entry.name}: alias ${alias}`);
    if (['skillvault-authoring', 'harness-report'].includes(entry.name)) {
      assert.ok(action.enum.includes('upsert'), `${entry.name}: one authoring action`);
      for (const alias of ['create', 'update']) assert.ok(!action.enum.includes(alias), `${entry.name}: alias ${alias}`);
    }
    if (entry.name === 'skillvault-discovery') {
      assert.deepEqual(action.enum, ['list', 'search', 'evaluate', 'explain']);
      const aliases = [...instructions.matchAll(/`(eval|expl)`\s*->\s*`([^`]+)`/g)]
        .map(([, alias, canonical]) => [alias, canonical]);
      assert.deepEqual(aliases, [['eval', 'evaluate'], ['expl', 'explain']]);
    }
  }
  const evaluation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discovery/references/evaluate.md'), 'utf8');
  assert.match(evaluation, /--chat-only/);
  assert.match(evaluation, /docs\/evaluations\//);
  assert.match(evaluation, /Do not change\s+target skills/);
});

test('decision bulletin separates optional configuration without hiding recorded decisions', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/planning/harness-decision');
  const workflow = fs.readFileSync(path.join(directory, 'references/workflow.md'), 'utf8');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-decision/skill.json');
  const action = manifest.inputs.find(input => input.name === 'action');
  assert.deepEqual(action.enum, ['list', 'record']);
  assert.equal(action.default, 'list');
  const rows = [...workflow.matchAll(/^\| (.+) \| (.+) \| (.+) \|\r?$/gm)]
    .map(([, request, mapping, display]) => ({ request, mapping, display }));
  const open = rows.find(row => row.request.includes('`list open`'));
  assert.match(open.mapping, /-Action Show -Filter Open/);
  assert.match(open.display, /one-line Configuration When Needed summary and source link/);
  const all = rows.find(row => row.request === '`list all`');
  assert.match(all.mapping, /-Action Show -Filter All/);
  assert.match(all.display, /Open decisions, recent decisions, then the detailed Configuration When Needed checklist/);
  assert.match(rows.find(row => row.request === '`list closed`').mapping, /-Action Show -Filter Closed/);
  assert.match(rows.find(row => row.request === '`list <decision-id>`').mapping, /-Action Show -Id <decision-id>/);
  const classification = workflow.split('### Decision Classification')[1].split('### Bulletin Display')[0].replace(/\s+/g, ' ');
  assert.match(classification, /Keep explicitly recorded `Open`\/`Proposed` decisions visible/);
  assert.match(classification, /Do not hide, resolve, or reclassify them/);
  assert.match(classification, /requested or already-enabled workflow needs a human choice that saved settings, inheritance, or existing defaults cannot resolve/);
  assert.match(classification, /Check environmental facts with available tools/);
  assert.match(classification, /a task status alone is not a decision/);
  assert.match(workflow, /Omit this section when no optional configuration is documented, and in closed or exact-ID views/);
  assert.match(workflow, /Do not start an interview, create IDs,\s+modify records, accept recommendations, install dependencies, or trigger work during display/);
  assert.match(workflow, /id,status,question,choice,recommendation,rationale,owner,recordedAt,reference,task,supersedes/);
  const plan = fs.readFileSync(path.join(root, 'docs/plans/2026-09-15-harness-command-and-record-contracts.md'), 'utf8');
  const setup = plan.split(/^## Configuration When Needed\r?$/m)[1]?.split(/^## /m)[0];
  assert.ok(setup, 'Keep the optional setup checklist separately addressable');
  assert.match(setup, /^\d+\. /m);
  assert.match(plan, /^## Open Decisions\r?$/m);
  assert.match(plan, /\[Configuration When Needed\]\(#configuration-when-needed\)/);
});

test('topic action-prefix ADR examples match canonical action menus', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const record = fs.readFileSync(path.join(root, 'docs/plans/decisions/2026-09-23-topic-action-prefix-matching-adr.md'), 'utf8');
  assert.match(record, /^- Status: Accepted\r?$/m);
  const examples = [...record.matchAll(/^\| `([^`]+)` \| ([^|]+) \| `([^`]+)` \|\r?$/gm)];
  assert.ok(examples.length > 0, 'Expected topic action-prefix examples');
  for (const [, topic, inputs, expectedAction] of examples) {
    const entry = catalog.find(candidate => candidate.name === topic);
    assert.ok(entry, `Unknown example topic: ${topic}`);
    const manifest = parseJson(fs.readFileSync(path.join(root, entry.path, 'skill.json'), 'utf8'), `${topic}/skill.json`);
    const actions = manifest.inputs.find(input => input.name === 'action').enum;
    const tokens = [...inputs.matchAll(/`([a-z]+)`/g)].map(([, token]) => token);
    assert.ok(tokens.length > 0, `Missing example input: ${topic}`);
    for (const token of tokens) {
      assert.ok([3, 4].includes(token.length), `${topic}: unsupported prefix ${token}`);
      const matches = actions.filter(action => action.startsWith(token));
      assert.deepEqual(matches, [expectedAction], `${topic}: ambiguous or unknown example ${token}`);
    }
  }
});

test('discovery evaluations separate optional runtime advice from the skill decision', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const evaluation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discovery/references/evaluate.md'), 'utf8');
  const output = evaluation.match(/## Output Shape[\s\S]*?```text\r?\n([\s\S]*?)```/)[1];
  const fields = new Map([...output.matchAll(/^([^:\r\n]+): (.+)$/gm)].map(([, name, value]) => [name, value.trim()]));
  assert.equal(fields.get('Skill recommendation'), 'upsert/defer/skip');
  assert.equal(fields.has('Recommendation'), false);
  for (const name of ['Standalone use', 'Harness integration']) assert.match(fields.get(name), /when relevant/);
  assert.match(evaluation, /do not authorize installation, execution, integration, or replacement/);

  const checklist = evaluation.split('## Behavior')[1].split('## Output Shape')[0];
  let contentIndent = 0;
  let nestedItems = 0;
  for (const line of checklist.split(/\r?\n/)) {
    const item = line.match(/^\d+\. /);
    if (item) contentIndent = item[0].length;
    const nested = line.match(/^( +)- /);
    if (nested) {
      nestedItems++;
      assert.ok(nested[1].length >= contentIndent, `Nested checklist item escapes its parent: ${line.trim()}`);
    }
  }
  assert.ok(nestedItems > 0, 'Expected nested evaluation checklist items');
});

test('discovery explains the requested tool or product without substituting or running a skill', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const explanation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discovery/references/explain.md'), 'utf8');
  assert.match(explanation, /Explain the requested subject first/);
  assert.match(explanation, /Ask only when the intended subject is genuinely ambiguous/);
  assert.match(explanation, /Do not substitute a related skill for the requested tool or product/);
  assert.match(explanation, /\/skillvault-discovery explain playwright/);
  assert.match(explanation, /Read-only: do not install, update, execute, rewrite, schedule, commit, or publish/);
});

test('topic operation guides keep local resource links inside their bundles', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const entry of catalog.filter(entry => /^(harness(?:-|$)|skillvault-|rules$|pr-watch$)/.test(entry.name))) {
    const directory = path.join(root, entry.path);
    const pending = [directory];
    while (pending.length) {
      const current = pending.pop();
      for (const resource of fs.readdirSync(current, { withFileTypes: true })) {
        const file = path.join(current, resource.name);
        if (resource.isDirectory()) { pending.push(file); continue; }
        if (!resource.name.endsWith('.md')) continue;
        const text = fs.readFileSync(file, 'utf8').replace(/```[^\n]*\n[\s\S]*?```/g, '');
        for (const match of text.matchAll(/\]\(([^\s)]+)\)/g)) {
          if (/^[a-z]+:|^#|^\//i.test(match[1])) continue;
          const target = path.resolve(path.dirname(file), decodeURIComponent(match[1].split('#')[0]));
          resolveInside(directory, path.relative(directory, target));
          assert.ok(fs.existsSync(target), `${path.relative(root, file)}: missing resource ${match[1]}`);
        }
      }
    }
  }
});

test('repository validation catches broken resources and catalog traversal', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skillvault-syntax-'));
  try {
    const relative = 'skills/testing/fixture';
    const directory = path.join(root, relative);
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(directory, 'SKILL.md'), validSkill);
    fs.writeFileSync(path.join(directory, 'skill.json'), JSON.stringify({ name: 'fixture', version: '1.0.0' }));
    fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', path: relative }]));
    assert.equal(validateRepository(root).publicCount, 1);
    fs.appendFileSync(path.join(directory, 'SKILL.md'), '\n[Missing](./missing.md)\n');
    assert.throws(() => validateRepository(root), /missing linked file/);
    fs.writeFileSync(path.join(directory, 'missing.md'), '# Resource');
    assert.equal(validateRepository(root).publicCount, 1);
    const backup = path.join(root, '.github/skills/.skillvault-backup-fixture');
    fs.cpSync(directory, backup, { recursive: true });
    const stage = path.join(root, '.github/skills/.skillvault-stage-fixture');
    fs.mkdirSync(stage, { recursive: true });
    fs.writeFileSync(path.join(stage, 'SKILL.md'), 'incomplete stage');
    assert.equal(validateRepository(root).installedCount, 0);
    const template = path.join(root, 'templates/new-skill-template/skill.json');
    fs.mkdirSync(path.dirname(template), { recursive: true });
    fs.writeFileSync(template, '{invalid}');
    assert.throws(() => validateRepository(root));
    fs.writeFileSync(template, JSON.stringify({ name: 'template', version: null }));
    assert.equal(validateRepository(root).publicCount, 1);
    fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', path: 'skills/public/testing/fixture' }]));
    assert.throws(() => validateRepository(root), /expected skills\/<category>\/<name>/);
    fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', path: '../escape' }]));
    assert.throws(() => validateRepository(root), /expected skills\/<category>\/<name>/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});