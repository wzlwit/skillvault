import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { parseJson, parseSkill, resolveInside, validateRepository, validateRuntimeInterfaces } from './validate-skill-files.mjs';

const validSkill = '---\nname: fixture\ndescription: A valid fixture\nargument-hint: "[<value>]"\nmetadata:\n  version: "1.0.0"\n---\n# Fixture\n';

// Old skill and command names retired on 2026-10-07 (and the three longer SkillVault topic names on 2026-10-09); current guidance must not accept or advertise them.
const retiredCommandNames = /(?<![\w./-])\/(?:harness|hn)(?![\w-])|(?<![\w./-])\/(?:harness|hn)-(?:task|test|link|policy|doc|comms|report|ref|restrict|fallback|root|loc|init|context|management|report-create|project|work|decision|timer)(?![\w-])|(?<![\w./-])\/schedule-manager(?![\w-])|(?<![\w./-])\/pr-review-(?:add|list|remove|timer)\b|(?<![\w/-])rules-core(?![\w-])|(?<![\w./-])\/(?:jarvis-metrics-create|kpi-dashboard-design|openapi-spec-generation|skillvault-refresh)\b|(?<![\w./-])\/(?:skillvault-installation|skillvault-discovery|skillvault-authoring|sv-installation|sv-discovery|sv-authoring)(?![\w-])/;

const harnessProcedures = {
  context: 'harness-setup/references/context.md',
  decision: 'harness-decide/references/workflow.md',
  dev: 'harness-dev/references/dev.md',
  doc: 'harness-write/references/doc.md',
  fallback: 'harness-setup/references/fallback.md',
  init: 'harness-setup/references/init.md',
  limits: 'harness-setup/references/limits.md',
  monitor: 'harness-monitor/references/workflow.md',
  report: 'harness-write/references/report.md',
  review: 'harness-review/references/workflow.md',
  root: 'harness-setup/references/root.md',
  task: 'harness-dev/references/task.md',
  test: 'harness-dev/references/test.md',
  timer: 'harness-schedule/references/project.md',
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

test('menu descriptions start with the menu, then Alone and Text, within the picker width', () => {
  const lead = '[broad|list] Alone: review your changes. Text: review that scope.';
  const menuSkill = validSkill.replace('argument-hint: "[<value>]"', 'argument-hint: "[broad|list] [<scope>]"');
  const leading = menuSkill.replace('description: A valid fixture', `description: "${lead} A valid fixture"`);
  assert.throws(() => parseSkill(menuSkill, 'fixture'), /menu and labels/);
  assert.throws(() => parseSkill(menuSkill.replace('description: A valid fixture', 'description: "[broad|list] A valid fixture"'), 'fixture'), /menu and labels/);
  assert.throws(() => parseSkill(menuSkill.replace('description: A valid fixture', 'description: "[broad] Alone: x. Text: y. A valid fixture"'), 'fixture'), /menu and labels/);
  assert.throws(() => parseSkill(menuSkill.replace('description: A valid fixture', 'description: "[broad|list] Alone: review every committed, staged, and untracked change. Text: review that scope."'), 'fixture'), /fit in 80/);
  assert.equal(parseSkill(leading, 'fixture').name, 'fixture');
  const oneWord = validSkill.replace('argument-hint: "[<value>]"', 'argument-hint: "[clean] [<target>]"');
  assert.throws(() => parseSkill(oneWord, 'fixture'), /menu and labels/, 'a one-word menu needs the same lead');
  assert.equal(parseSkill(oneWord.replace('description: A valid fixture', 'description: "[clean] Alone: all schedules. Text: set one. A valid fixture"'), 'fixture').name, 'fixture');
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skillvault-actions-'));
  try {
    const relative = 'skills/testing/fixture';
    const directory = path.join(root, relative);
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(directory, 'SKILL.md'), leading);
    const write = (manifestDescription, catalogDescription) => {
      fs.writeFileSync(path.join(directory, 'skill.json'), JSON.stringify({ name: 'fixture', version: '1.0.0', description: manifestDescription }));
      fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', description: catalogDescription, path: relative, version: '1.0.0' }]));
    };
    write('A valid fixture', `${lead} A valid fixture`);
    assert.throws(() => validateRepository(root), /skill\.json description/);
    write(`${lead} A valid fixture`, 'A valid fixture');
    assert.throws(() => validateRepository(root), /catalog description/);
    write(`${lead} A valid fixture`, `${lead} A valid fixture`);
    assert.equal(validateRepository(root).publicCount, 1);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

test('catalog, skill.json, and SKILL.md share one description', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skillvault-description-'));
  try {
    const relative = 'skills/testing/fixture';
    const directory = path.join(root, relative);
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(directory, 'SKILL.md'), validSkill);
    const write = (manifestDescription, catalogDescription) => {
      fs.writeFileSync(path.join(directory, 'skill.json'), JSON.stringify({ name: 'fixture', version: '1.0.0', description: manifestDescription }));
      fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', description: catalogDescription, path: relative, version: '1.0.0' }]));
    };
    write('A valid fixture', 'A shorter fixture');
    assert.throws(() => validateRepository(root), /catalog description must match skill\.json/);
    write('A different fixture', 'A different fixture');
    assert.throws(() => validateRepository(root), /SKILL\.md description must match skill\.json/);
    write('A valid fixture', 'A valid fixture');
    assert.equal(validateRepository(root).publicCount, 1);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
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
    ['harness-schedule', 'harness-runtime'],
    ['pr-review', 'harness-runtime'],
    ['skillvault-author', 'skillvault-install'],
    ['harness-schedule', 'skillvault-install'],
  ]) {
    assert.equal(manifests.get(caller).install.defaultScope, manifests.get(helper).install.defaultScope, `${caller} requires sibling ${helper}`);
  }
});

test('chart selection preserves data evidence and requirement-first fallback', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const content = fs.readFileSync(path.join(root, 'skills/data/kpi-dashboard/SKILL.md'), 'utf8');
  const selection = content.split('## Profile Before Chart Selection')[1].split('## Calculation and Performance Guidance')[0];
  assert.ok(content.includes('(#profile-before-chart-selection)'));
  assert.match(selection, /Explicit requirements[\s\S]*take precedence\s+over defaults/);
  assert.match(selection, /valid requested view[\s\S]*no mandatory profiling round trip/);
  assert.match(selection, /uncertain[\s\S]*authorized for inspection/);
  assert.match(selection, /data types, cardinality, representative values,[\s\S]*entity-versus-detail grain/);
  assert.match(selection, /uniqueness does not establish the business entity/);
  assert.match(selection, /Do not silently discard unusual rows/);
  assert.match(selection, /Design-only work stays design-only/);
  assert.match(selection, /existing retry and time budgets/);
  assert.match(selection, /timeout\s+does not prove the prior process stopped/);
  assert.match(selection, /Preserve pauses and ownership/);
  assert.match(selection, /Ask before changing[\s\S]*data coverage, or sampling requirement/);
  assert.match(selection, /Refusal or no answer leaves that change pending/);
  assert.match(selection, /sample cannot establish whole-dataset totals/);
  assert.match(selection, /missing evidence Unverified and incomplete\s+scope Partial/);
});

test('chart evidence and fallback preserve the report contract', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-write/references/report.md'), 'utf8');
  const fallback = workflow.split('## Requirement-Preserving Fallback')[1].split('## Validate and Deliver')[0];
  const validation = workflow.split('## Validate and Deliver')[1].split('## Optional Monitoring Handoff')[0];
  assert.ok(workflow.includes('(#requirement-preserving-fallback)'));
  assert.match(fallback, /Honor explicit tool, platform, format, chart-type, and data-scope requirements/);
  assert.match(fallback, /retry eligibility, and remaining time budget/);
  assert.match(fallback, /Before retrying or switching methods[\s\S]*reconcile possible file or remote writes/);
  assert.match(fallback, /Do not start a competing writer, clear a pause, or kill an unrelated process/);
  assert.match(fallback, /approved reader or renderer[\s\S]*artifact identity/);
  assert.match(fallback, /same metric, data, output, and acceptance contract/);
  assert.match(fallback, /Ask before changing[\s\S]*sampling requirement[\s\S]*design-only/);
  assert.match(fallback, /Refusal or no answer leaves the change pending/);
  assert.match(fallback, /Missing evidence stays Unverified; incomplete deliverables remain Partial or Blocked/);
  assert.match(validation, /each numeric claim with the final plotted\s+data/);
  assert.match(validation, /series selection[\s\S]*units, time\s+window, population/);
  assert.match(validation, /sample preview alone cannot prove totals or extrema/);
  assert.match(validation, /each failed chart in a\s+batch/);
  assert.match(validation, /Exclude non-displayed\s+sensitive columns/);
  assert.match(validation, /bare chart does not require\s+an added narrative/);
  assert.match(validation, /keep dependent claims Unverified/);
});

test('editable report acceptance distinguishes native data and conditional checks', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-write/references/report.md'), 'utf8');
  const contract = workflow.split('### Editability Acceptance')[1].split('## Dispatch and Write')[0];
  const validation = workflow.split('## Validate and Deliver')[1].split('## Optional Monitoring Handoff')[0];
  assert.ok(workflow.includes('(#editability-acceptance)'));
  assert.match(contract, /required object types and editing actions/);
  assert.match(contract, /Edit Data requires a\s+data-backed chart; editable shapes[\s\S]*insufficient/);
  assert.match(contract, /appearance\s+does not prove its inherited objects can be edited/);
  assert.match(contract, /Image-only requests acquire no native-editability requirement/);
  assert.match(contract, /Design-only[\s\S]*without requiring an application trial/);
  assert.match(contract, /add no platform route or renderer/);
  assert.match(validation, /actual object types and data[\s\S]*edit, save, and reopen in the intended application/);
  assert.match(validation, /preview or file extension cannot prove editability/);
  assert.match(validation, /unsupported\s+or flattened objects[\s\S]*acceptance Unverified/);
  assert.match(validation, /do not label the artifact Validated until the required checks pass/);
  assert.match(validation, /fallback preserves[\s\S]*approval, ownership, pause, and budget rules/);
});

test('workbook acceptance preserves formulas and distinguishes caches from verified results', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-write/references/report.md'), 'utf8');
  const workbook = workflow.split('### Workbook Acceptance')[1].split('## Dispatch and Write')[0];
  const validation = workflow.split('## Validate and Deliver')[1].split('## Optional Monitoring Handoff')[0];
  assert.ok(workflow.includes('(#workbook-acceptance)'));
  assert.match(workbook, /workbook supplies report figures or forms part of an approved deliverable/);
  assert.match(workbook, /formula expressions and cached results separately/);
  assert.match(workbook, /blank cache[\s\S]*do not infer zero or missing business data/);
  assert.match(workbook, /preserve formulas, macros, and external\s+references/);
  assert.match(workbook, /Do not save a values-only view over a formula workbook/);
  assert.match(workbook, /approved engine compatible with the workbook/);
  assert.match(workbook, /retain the original[\s\S]*source mutation needs its own approval/);
  assert.match(workbook, /structured result and full error counts[\s\S]*formula errors fail acceptance even with exit\s+code zero/);
  assert.match(workbook, /expected values, ranges, and any required spill results/);
  assert.match(workbook, /Missing or stale results remain Unverified/);
  assert.match(workbook, /Values-only CSV input and unchanged workbooks[\s\S]*need no forced recalculation/);
  assert.match(workbook, /Design-only work[\s\S]*without running a calculation engine/);
  assert.match(workbook, /add no XLSX route or upstream dependency/);
  assert.match(validation, /workbook acceptance[\s\S]*before marking\s+the report Validated/);
});

test('branded output preserves authority and font limitations without mandatory setup', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const content = fs.readFileSync(path.join(root, 'skills/data/kpi-dashboard/SKILL.md'), 'utf8');
  const brand = content.split('## Brand and Template Authority')[1].split('## Profile Before Chart Selection')[0];
  assert.ok(content.includes('(#brand-and-template-authority)'));
  assert.match(brand, /source\/revision,[\s\S]*palette, title\/body and language-specific fonts,[\s\S]*permitted variation/);
  assert.match(brand, /visual appearance from required template structure/);
  assert.match(brand, /sampled colors and inferred fonts as estimates, not official values/);
  assert.match(brand, /official\s+palette takes precedence over a screenshot estimate/);
  assert.match(brand, /Clarify material conflicts/);
  assert.match(brand, /implementation is in scope[\s\S]*check representative output/);
  assert.match(brand, /unavailable required font[\s\S]*until an alternative is approved/);
  assert.match(brand, /do not silently\s+substitute fonts, install them, or alter the source template/);
  assert.match(brand, /Design-only work[\s\S]*without claiming a rendering test/);
  assert.match(brand, /Unbranded work[\s\S]*without mandatory brand paperwork/);
  assert.match(content, /Carry agreed brand\/template requirements[\s\S]*existing presentation handoff/);
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
  assert.match(manifest.upstream.commit, /^[a-f0-9]{40}$/);
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
  const topics = ['setup', 'dev', 'write', 'review', 'decide', 'monitor', 'schedule'].map(suffix => `harness-${suffix}`);
  assert.deepEqual(catalog.filter(entry => entry.name === 'harness' || entry.name.startsWith('harness-')).map(entry => entry.name).sort(), ['harness-runtime', ...topics].sort());
  const runtimeEntry = catalog.find(entry => entry.name === 'harness-runtime');
  assert.equal(runtimeEntry.path, 'skills/planning/harness-runtime');
  const runtimeDirectory = path.join(root, runtimeEntry.path);
  const runtimeManifest = parseJson(fs.readFileSync(path.join(runtimeDirectory, 'skill.json'), 'utf8'), 'harness-runtime/skill.json');
  const runtimeSkill = parseSkill(fs.readFileSync(path.join(runtimeDirectory, 'SKILL.md'), 'utf8'), 'harness-runtime', runtimeManifest);
  assert.equal(runtimeSkill['user-invocable'], false, 'The shared runtime stays out of the slash menu');
  assert.equal(runtimeSkill['disable-model-invocation'], true, 'The shared runtime is never loaded as a topic');
  assert.equal(runtimeManifest.inputs, undefined, 'The shared runtime has no actions of its own');
  assert.match(runtimeSkill.description, /harness-setup/);
  assert.equal(runtimeManifest.install.defaultScope, 'global');
  for (const file of ['scripts/harness.ps1', 'scripts/review-models.json', 'references/runtime.md']) {
    assert.ok(fs.existsSync(path.join(runtimeDirectory, file)), `The shared runtime keeps ${file} in place`);
  }
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
    const shortcut = name.replace('harness-', 'hn-');
    assert.match(skill.description, new RegExp(`/${shortcut}(?![\\w-])`));
    assert.match(instructions, /shorthand for the same topic, not a separate skill or folder/);
    assert.notEqual(skill['user-invocable'], false);
    // The hint starts with the menu; alone is not an action, so the action input has no default.
    assert.match(skill['argument-hint'], /^\[[a-z]+(?:\|[a-z]+)*\] /);
    assert.equal(manifest.inputs.find(input => input.name === 'action').default, undefined);
    assert.equal((manifest.dependencies ?? []).some(dependency => dependency.startsWith('hn-')), false);
  }
  // Every current skill's catalog entry, manifest, and guides stay free of retired names. The installer's
  // former-name map and the bootstrap legacy lists keep them only to retire old installed copies.
  for (const entry of catalog) {
    const directory = path.join(root, entry.path);
    const pending = [directory];
    const texts = [entry.description];
    while (pending.length) {
      const current = pending.pop();
      for (const item of fs.readdirSync(current, { withFileTypes: true })) {
        const file = path.join(current, item.name);
        if (item.isDirectory()) { pending.push(file); continue; }
        if (item.name === 'skill.json' || item.name.endsWith('.md')) texts.push(fs.readFileSync(file, 'utf8'));
      }
    }
    for (const text of texts) assert.doesNotMatch(text, retiredCommandNames, `${entry.name} still accepts or advertises a retired name`);
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
  for (const retired of ['harness', 'harness-comms', 'harness-context', 'harness-decision', 'harness-doc', 'harness-fallback', 'harness-init', 'harness-link', 'harness-loc', 'harness-management', 'harness-policy', 'harness-ref', 'harness-report', 'harness-report-create', 'harness-restrict', 'harness-root', 'harness-task', 'harness-test', 'harness-project', 'harness-work', 'harness-timer', 'hn', 'hn-decision', 'hn-management', 'hn-timer']) {
    assert.equal(fs.existsSync(path.join(root, 'skills/planning', retired)), false, `Do not retain a duplicate ${retired} source bundle`);
  }
  for (const [current, former, category] of [['skillvault-install', 'skillvault-installation', 'core'], ['skillvault-discover', 'skillvault-discovery', 'core'], ['skillvault-author', 'skillvault-authoring', 'core'], ['harness-setup', 'harness-project', 'planning'], ['harness-dev', 'harness-work', 'planning'], ['harness-decide', 'harness-decision', 'planning'], ['harness-schedule', 'harness-timer', 'planning'], ['schedule-manage', 'schedule-manager', 'system']]) {
    assert.equal(fs.existsSync(path.join(root, 'skills', category, former)), false, `${current} replaced ${former}`);
  }
});

test('harness communications stay draft-only with bundled slot ranking', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'harness-write');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-write/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.path, 'skills/planning/harness-write');
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['slots']);
  assert.deepEqual(manifest.inputs.find(input => input.name === 'kind').enum, ['doc', 'tracker', 'meeting', 'email', 'report']);
  assert.ok(manifest.dependencies.includes('rules'));
  assert.match(content, /without\s+requiring an initialized harness/);
  assert.match(content, /\*\*Drafts only\.\*\*/);
  assert.match(skill.description, /never sends, invites, shares, or publishes without explicit approval/);
  for (const reference of ['comms', 'meeting', 'email', 'tracker']) {
    assert.ok(fs.existsSync(path.join(directory, `references/${reference}.md`)), `Missing ${reference} guide`);
  }
  assert.ok(fs.existsSync(path.join(directory, 'scripts/rank-slots.ps1')));
  const workflow = fs.readFileSync(path.join(directory, 'references/comms.md'), 'utf8');
  assert.match(workflow, /Commit authors, managers, and\s+directory titles only suggest candidates/);
  assert.match(workflow, /Re-read before every write/);
  const meeting = fs.readFileSync(path.join(directory, 'references/meeting.md'), 'utf8');
  assert.match(meeting, /\*\*Save as draft\*\*\. Never choose \*\*Send\*\*/);
  const projectGuide = fs.readFileSync(path.join(root, 'skills/planning/harness-setup/SKILL.md'), 'utf8');
  assert.match(projectGuide, /`\/harness-write` works without initialization/);
  for (const name of ['harness-monitor']) {
    const counterpart = catalog.find(candidate => candidate.name === name);
    const counterpartManifest = parseJson(fs.readFileSync(path.join(root, counterpart.path, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const counterpartSkill = parseSkill(fs.readFileSync(path.join(root, counterpart.path, 'SKILL.md'), 'utf8'), name, counterpartManifest);
    assert.ok(skill.description.includes(name));
    for (const description of [counterpart.description, counterpartManifest.description, counterpartSkill.description]) {
      assert.ok(description.includes('harness-write'), `Declare the communications overlap for ${name}`);
    }
  }
  const bundleText = ['SKILL.md', 'references/comms.md', 'references/meeting.md', 'references/email.md', 'references/tracker.md']
    .map(file => fs.readFileSync(path.join(directory, file), 'utf8')).join('\n');
  assert.doesNotMatch(bundleText, /@(?!example\.com)[a-z0-9-]+\.(?:com|net|org)\b/i, 'Use example.com addresses in the public bundle');
});

test('harness documentation declares standalone authoring and post-Humanizer validation', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'harness-write');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-write/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.path, 'skills/planning/harness-write');
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['slots'], 'text writes; slots is the only menu word');
  assert.deepEqual(manifest.inputs.find(input => input.name === 'audience').enum, ['internal', 'partner', 'public']);
  for (const dependency of ['rules', 'humanizer']) assert.ok(manifest.dependencies.includes(dependency), `Documentation still needs ${dependency}`);
  assert.equal(manifest.requiredInterfaces, undefined);
  assert.match(content, /without\s+requiring\s+an initialized harness/);
  assert.match(content, /^\| Text \| [^\r\n]*\]\(\.\/references\/doc\.md\)/m, 'text routes doc requests to the doc guide');
  const workflow = fs.readFileSync(path.join(directory, 'references/doc.md'), 'utf8');
  const phases = ['## Resolve the request', '## Gather evidence', '## Draft the set', '## Humanizer pass', '## Validate and deliver'];
  const positions = phases.map(phase => workflow.indexOf(phase));
  assert.ok(positions.every((position, index) => position >= 0 && (index === 0 || position > positions[index - 1])));
  assert.match(workflow, /If it is not\s+installed, fetch and read its authoritative upstream guidance/);
  assert.match(workflow, /Freeze headings and explicit anchors/);
  assert.match(workflow, /Draft \| Files exist, but essential evidence, Humanizer, or required validation is incomplete/);
  const template = fs.readFileSync(path.join(directory, 'references/doc-set.md'), 'utf8');
  const outline = parseJson(/```json\r?\n([\s\S]*?)\r?\n```/.exec(template)[1], 'doc-set outline');
  assert.deepEqual(outline.pages.map(page => page.purpose), ['overview', 'rationale', 'glossary', 'lifecycle', 'onboarding', 'deep-topic', 'troubleshooting']);
  assert.equal(new Set(outline.pages.map(page => page.file)).size, outline.pages.length);
  const decision = catalog.find(candidate => candidate.name === 'architecture-decision-records');
  const decisionManifest = parseJson(fs.readFileSync(path.join(root, decision.path, 'skill.json'), 'utf8'), 'architecture-decision-records/skill.json');
  const decisionSkill = parseSkill(fs.readFileSync(path.join(root, decision.path, 'SKILL.md'), 'utf8'), decision.name, decisionManifest);
  for (const description of [decision.description, decisionManifest.description, decisionSkill.description]) assert.ok(description.includes('harness-write'));
});

test('paginated document acceptance checks final pages without widening Markdown output', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-write/references/doc.md'), 'utf8');
  const validation = workflow.split('## Validate and deliver')[1].split('## Optional restructuring and publication')[0];
  assert.ok(workflow.indexOf('## Humanizer pass') < workflow.indexOf('## Validate and deliver'));
  assert.match(validation, /When PDF\/DOCX is an agreed deliverable/);
  assert.match(validation, /inspect all final rendered pages after Humanizer and any\s+layout-affecting edits/);
  assert.match(validation, /clipping, page breaks, split tables, captions, headers\/footers/);
  assert.match(validation, /font\/glyph coverage for the required languages[\s\S]*mixed-language/);
  assert.match(validation, /passing XML validation does not prove readable pagination/);
  assert.match(validation, /available, authorized renderers/);
  assert.match(validation, /Missing rendering or unresolved page defects keeps the\s+artifact Draft/);
  assert.match(validation, /do not install software or substitute another\s+format without approval/);
  assert.match(validation, /Markdown-only output requires no Word\/PDF conversion/);
});

test('docs, communications, PR descriptions, and ADRs spell out acronyms at first use', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
  const sources = {
    'harness-write': read('skills/planning/harness-write/SKILL.md'),
    'doc pages': read('skills/planning/harness-write/references/doc-set.md'),
    'pr-publish': read('skills/github/pr-publish/references/description.md'),
    'ADR wrapper': read('skills/writing/architecture-decision-records/SKILL.md').split('<!-- upstream:begin -->')[0],
  };
  for (const [name, text] of Object.entries(sources)) {
    assert.match(text, /[Ss]pell out each (?:acronym|abbreviation)[\s\S]{0,40}where it first appears/, `${name} spells out acronyms at first use`);
    assert.match(text, /URL, PDF, JSON,\s+or HTML/, `${name} limits the exception to well-known acronyms`);
    assert.match(text, /short\s+form, such as DAS\s+or\s+PACS/, `${name} lets names that go by their short form stay short`);
  }
  assert.match(sources['harness-write'], /In docs and communications/);
  const humanizerPass = read('skills/planning/harness-write/references/doc.md').split('## Humanizer pass')[1].split('## Validate and deliver')[0];
  assert.match(humanizerPass, /first-use abbreviation expansions/);
  assert.match(humanizerPass, /moves an abbreviation's\s+first use, move its expansion there/);
});

test('Humanizer installs its original while humanizer-ch keeps its Chinese guide', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const original = catalog.find(candidate => candidate.name === 'humanizer');
  const originalManifest = parseJson(fs.readFileSync(path.join(root, original.path, 'skill.json'), 'utf8'), 'humanizer/skill.json');
  assert.equal(originalManifest.install.strategy, 'upstream');
  assert.equal(originalManifest.upstream.repo, 'https://github.com/blader/humanizer');
  assert.equal(originalManifest.upstream.version, 'latest');
  assert.equal(original.description, originalManifest.description);
  assert.ok(original.description.includes('humanizer-ch'));

  const entry = catalog.find(candidate => candidate.name === 'humanizer-ch');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'humanizer-ch/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, 'humanizer-ch', manifest);
  assert.equal(entry.version, null);
  assert.equal(manifest.kind, 'reference');
  assert.equal(manifest.install.defaultScope, 'global');
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.ok(skill.description.includes('humanizer'));
  assert.match(content, /fetch and read the (?:authoritative )?upstream (?:guidance|instructions)/);
  assert.equal(fs.existsSync(path.join(directory, 'scripts')), false);
  assert.equal(fs.existsSync(path.join(directory, 'agents/openai.yaml')), false);
  assert.equal(entry.path, 'skills/writing/humanizer-ch');
  assert.equal(manifest.author, null);
  assert.equal(manifest.license, null);
  assert.equal(manifest.upstream.license, null);
  assert.equal(manifest.upstream.repo, 'https://github.com/zjqc/humanizer-ch');
  assert.match(manifest.upstream.revision, /^[a-f0-9]{40}$/);
  assert.match(content, /No upstream rewriting rules, examples, scripts, or Codex UI files are bundled/);
  assert.match(content, /not a general Chinese-language\s+replacement/);
  assert.match(content, /not an upstream example or a validated Chinese editing result/);
  assert.match(content, /\/humanizer-ch [\u4e00-\u9fff]/);
  assert.deepEqual(manifest.dependencies ?? [], []);
});

test('PPT Master installs its original and keeps counterpart overlap notes', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'ppt-master');
  assert.equal(entry.path, 'skills/writing/ppt-master');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'ppt-master/skill.json');
  assert.equal(entry.version, null);
  assert.equal(manifest.kind, 'reference');
  assert.equal(manifest.author, 'Hugo He');
  assert.equal(manifest.license, 'MIT');
  assert.equal(manifest.install.strategy, 'upstream');
  assert.equal(manifest.upstream.repo, 'https://github.com/hugohe3/ppt-master');
  assert.equal(manifest.upstream.path, 'skills/ppt-master');
  assert.equal(manifest.upstream.version, 'latest');
  assert.equal(manifest.upstream.license, 'MIT');
  assert.equal(entry.description, manifest.description);
  assert.deepEqual(fs.readdirSync(directory), ['skill.json']);
  assert.deepEqual(manifest.dependencies ?? [], []);
  for (const name of ['harness-write', 'kpi-dashboard']) {
    assert.ok(manifest.description.includes(name));
    const counterpart = catalog.find(candidate => candidate.name === name);
    const counterpartManifest = parseJson(fs.readFileSync(path.join(root, counterpart.path, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const counterpartSkill = parseSkill(fs.readFileSync(path.join(root, counterpart.path, 'SKILL.md'), 'utf8'), name, counterpartManifest);
    for (const description of [counterpart.description, counterpartManifest.description, counterpartSkill.description]) {
      assert.ok(description.includes('ppt-master'), `Declare the reference overlap for ${name}`);
    }
    assert.equal((counterpartManifest.dependencies ?? []).includes('ppt-master'), false);
  }
});

test('office documents reference separates original navigation from proprietary upstream tools', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'office-documents');
  assert.equal(entry.path, 'skills/writing/office-documents');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'office-documents/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.version, null);
  assert.equal(manifest.version, null);
  assert.equal(manifest.kind, 'reference');
  assert.equal(manifest.author, 'Anthropic, PBC');
  assert.equal(manifest.license, null);
  assert.equal(manifest.upstream.repo, 'https://github.com/anthropics/skills');
  assert.equal(manifest.upstream.path, 'skills');
  assert.equal(manifest.upstream.license, 'Proprietary');
  assert.match(manifest.upstream.revision, /^[a-f0-9]{40}$/);
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.deepEqual(fs.readdirSync(directory).sort(), ['SKILL.md', 'skill.json']);
  for (const name of ['pdf', 'docx', 'xlsx']) {
    assert.ok(content.includes(`/blob/${manifest.upstream.revision}/skills/${name}/SKILL.md`));
  }
  assert.match(content, /No upstream\s+prompts, scripts, examples, assets, or document-processing dependencies are bundled/);
  assert.match(content, /fetch and read the selected instructions and\s+their license/);
  assert.match(content, /applicable agreement permits that use/);
  assert.match(content, /not a universal lossless merger/);
  assert.match(content, /Do not infer Apache licensing/);
  assert.match(content, /reference grants no rights to the upstream materials/);
  assert.match(content, /does not certify file preservation, calculation accuracy, or Chinese\/mixed-language rendering/);
  for (const name of ['harness-write']) {
    assert.ok(skill.description.includes(name));
    const counterpart = catalog.find(candidate => candidate.name === name);
    const counterpartManifest = parseJson(fs.readFileSync(path.join(root, counterpart.path, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const counterpartSkill = parseSkill(fs.readFileSync(path.join(root, counterpart.path, 'SKILL.md'), 'utf8'), name, counterpartManifest);
    for (const description of [counterpart.description, counterpartManifest.description, counterpartSkill.description]) {
      assert.ok(description.includes('office-documents'), `Declare the reference overlap for ${name}`);
    }
    assert.equal((counterpartManifest.dependencies ?? []).includes('office-documents'), false);
  }
});

test('RAG implementation adapts the original with explicit example limits', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'rag-implementation');
  assert.equal(entry.path, 'skills/data/rag-implementation');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'rag-implementation/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  const wrapper = content.split('<!-- upstream:begin -->')[0];
  assert.equal(entry.version, null);
  assert.equal(manifest.version, null);
  assert.equal(manifest.author, 'Seth Hobson');
  assert.equal(manifest.maintainer, 'wzlwit');
  assert.equal(manifest.license, 'MIT');
  assert.equal(manifest.source.repo, 'skillvault');
  assert.equal(manifest.source.path, entry.path);
  assert.equal(manifest.install.strategy, 'adapted');
  assert.equal(manifest.upstream.repo, 'https://github.com/wshobson/agents');
  assert.equal(manifest.upstream.path, 'plugins/llm-application-dev/skills/rag-implementation');
  assert.equal(manifest.upstream.version, 'latest');
  assert.equal(manifest.upstream.license, 'MIT');
  assert.match(manifest.upstream.commit, /^[a-f0-9]{40}$/);
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.ok(fs.existsSync(path.join(directory, 'references/details.md')));
  assert.match(wrapper, /installing this skill runs nothing/);
  assert.match(wrapper, /global\s+installation default does not authorize a new installation/);
  assert.match(wrapper, /legacy `langchain\.retrievers` and `langchain\.storage` imports/);
  assert.match(wrapper, /does not guard empty retrieval, empty relevance sets, or empty test sets/);
  assert.match(wrapper, /stable source IDs, revisions, and supporting passages/);
  assert.match(wrapper, /retrieved text as untrusted evidence, not instruction authority/);
  assert.match(wrapper, /adds no harness action, runtime dependency, or automatic ingestion/);
});

test('gamedev reference links upstream without bundling or installing it', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'awesome-gamedev-agent-skills');
  assert.equal(entry.path, 'skills/gamedev/awesome-gamedev-agent-skills');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'awesome-gamedev-agent-skills/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.version, null);
  assert.equal(manifest.version, null);
  assert.equal(manifest.kind, 'reference');
  assert.equal(manifest.author, 'Abhishek Barali and the awesome-gamedev-agent-skills contributors');
  assert.equal(manifest.maintainer, 'wzlwit');
  assert.equal(manifest.source.path, entry.path);
  assert.equal(manifest.upstream.repo, 'https://github.com/gamedev-skills/awesome-gamedev-agent-skills');
  assert.equal(manifest.upstream.version, null);
  assert.equal(manifest.upstream.license, 'Apache-2.0');
  assert.match(manifest.upstream.revision, /^[a-f0-9]{40}$/);
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.deepEqual(fs.readdirSync(directory).sort(), ['SKILL.md', 'skill.json']);
  for (const resource of ['router/SKILL.md', 'router/references/routing-table.md', 'docs/VERSION-SUPPORT.md', 'NOTICE']) {
    assert.ok(content.includes(`/blob/${manifest.upstream.revision}/${resource}`));
  }
  assert.match(content, /Fetch and read the upstream instructions/);
  assert.match(content, /No upstream skills, router files, scripts, or assets are bundled/);
  assert.match(content, /No installation or execution is implied/);
  assert.match(content, /need the user's approval/);
});

test('document evidence distinguishes partial extraction from complete coverage', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-write/references/doc.md'), 'utf8');
  const evidence = workflow.split('## Gather evidence')[1].split('## Draft the set')[0];
  assert.match(evidence, /requested files\/sections with those actually read/);
  assert.match(evidence, /skipped or unreadable inputs[\s\S]*existing claim\/source map/);
  assert.match(evidence, /source-plus-section identities with edition\/revision/);
  assert.match(evidence, /task-critical tables, code,[\s\S]*reading order against the original/);
  assert.match(evidence, /OCR uncertainty, missing images/);
  assert.match(evidence, /Successful extraction or aggregate counts do not prove complete or faithful coverage/);
  assert.match(evidence, /missing or distorted content[\s\S]*affected guidance\s+Draft/);
  assert.match(evidence, /explicitly requested subset need not\s+read unrelated chapters/);
  assert.match(evidence, /already-readable Markdown\/text without a conversion dependency/);
  assert.match(evidence, /does not authorize[\s\S]*uploading documents/);
});

test('SkillVault topics register full names and keep sv as conversational shortcuts', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const topics = ['author', 'discover', 'install'].map(suffix => `skillvault-${suffix}`);
  assert.deepEqual(catalog.filter(entry => entry.name.startsWith('skillvault-')).map(entry => entry.name).sort(), topics);
  // Retired command spellings stay out of current guidance; the installer's former-name map still retires old copies.
  const retiredNames = /(?<![\w./-])\/?(?:skillvault|sv|skv)-(?:installation|discovery|authoring|list|uninstall|search|evaluate|key-points|upsert|remove|source|fresh|sync|refresh)(?![\w.-])|\/skv-/;
  for (const name of topics) {
    const entry = catalog.find(candidate => candidate.name === name);
    assert.equal(entry.path, `skills/core/${name}`);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const skill = parseSkill(instructions, name, manifest);
    const shortcut = name.replace('skillvault-', 'sv-');
    assert.equal(manifest.name, name);
    assert.equal(manifest.source.path, entry.path);
    assert.notEqual(skill['user-invocable'], false);
    assert.match(skill.description, new RegExp(`/${shortcut}(?![\\w-])`));
    assert.equal(fs.existsSync(path.join(root, 'skills/core', shortcut)), false);
    assert.equal((manifest.dependencies ?? []).some(dependency => dependency.startsWith('sv-')), false);
    for (const text of [entry.description, manifest.description, instructions]) assert.doesNotMatch(text, retiredNames, `${name} still advertises a retired name`);
  }
  for (const retired of ['skillvault-source', 'skillvault-refresh']) assert.equal(fs.existsSync(path.join(root, 'skills/core', retired)), false, `Do not retain the retired ${retired} bundle`);
  const installation = path.join(root, 'skills/core/skillvault-install');
  const manifest = parseJson(fs.readFileSync(path.join(installation, 'skill.json'), 'utf8'), 'skillvault-install/skill.json');
  assert.ok(manifest.inputs.find(input => input.name === 'action').enum.includes('refresh'));
  assert.equal(manifest.ownershipProtocol, 1, 'The refresh runtime reports ownership');
  assert.equal(manifest.runtimeInterfaces['structured-refresh'], 2);
  for (const file of ['scripts/skill-refresh.ps1', 'references/refresh.md']) assert.ok(fs.existsSync(path.join(installation, file)), `Missing ${file}`);
  const timer = parseJson(fs.readFileSync(path.join(root, 'skills/planning/harness-schedule/skill.json'), 'utf8'), 'harness-schedule/skill.json');
  assert.equal(timer.requiredInterfaces['skillvault-install']['structured-refresh'], 2);
  assert.equal((timer.dependencies ?? []).includes('skillvault-refresh'), false);
  const bootstrap = parseJson(fs.readFileSync(path.join(root, 'scripts/bootstrap-skills.json'), 'utf8'), 'bootstrap-skills.json');
  assert.equal(bootstrap.includes('skillvault-refresh'), false);
});

test('experience-driven authoring keeps learning destinations and edit authority separate', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-author');
  const workflow = fs.readFileSync(path.join(directory, 'references/upsert.md'), 'utf8');
  const experience = workflow.split('## Improve from Task Experience')[1].split('## Upsert By Name')[0];
  const destinations = [...experience.matchAll(/^\| ([^|]+) \| ([^|]+) \|\r?$/gm)]
    .map(([, lesson, destination]) => ({ lesson, destination }));
  assert.ok(destinations.some(row => /procedure/.test(row.lesson) && /Existing owning skill/.test(row.destination)));
  assert.ok(destinations.some(row => /fact or user preference/.test(row.lesson) && /Existing host memory/.test(row.destination)));
  assert.ok(destinations.some(row => /one repository/.test(row.lesson) && /approved editing scope/.test(row.destination)));
  assert.ok(destinations.some(row => /working rule/.test(row.lesson) && /confirmation/.test(row.destination)));
  assert.ok(destinations.some(row => /unsupported inference/.test(row.lesson) && /No durable change/.test(row.destination)));
  assert.match(experience, /Choosing a destination does not authorize writing to it/);
  assert.match(experience, /Do not add an automatic\s+end-of-task writer/);
  assert.match(experience, /git diff --no-index[\s\S]*exit code 1 for expected differences/);
  assert.match(experience, /original case and a nearby case where it\s+should not apply/);
  assert.match(experience, /not an executed agent test/);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-author/skill.json');
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['remove']);

  const management = fs.readFileSync(path.join(root, 'skills/core/rules/references/manage.md'), 'utf8');
  const proposal = management.split('## Lessons Proposed as Rules')[1].split('## Confirmed Edit Procedure')[0];
  assert.match(proposal, /expected command result/);
  assert.match(proposal, /nearby\s+valid case/);
  assert.match(proposal, /leave deferred choices unresolved/);
  assert.match(proposal, /low-risk does not waive confirmation/);
  assert.match(management, /Wait for explicit confirmation unless the current request already approves the exact text/);
  const core = fs.readFileSync(path.join(root, 'skills/core/rules/references/core.md'), 'utf8');
  assert.equal([...core.matchAll(/^\d\. \*\*/gm)].length, 4);
});

test('upsert writes only to the repository and never installs', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-author');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-author/skill.json');
  assert.equal(manifest.inputs.some(input => input.name === 'scope'), false);
  assert.equal(manifest.outputs.includes('install-summary'), false);
  const entrypoint = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  assert.match(entrypoint, /Upsert never installs/);
  const workflow = fs.readFileSync(path.join(directory, 'references/upsert.md'), 'utf8');
  const after = workflow.split('## After Upsert')[1].split('## Validation')[0];
  assert.match(after, /Upsert never installs a skill/);
  assert.match(after, /`\/skillvault-install <name>`/);
});

test('upsert from a URL adds an external skill as a latest reference by default', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-author/references/upsert.md'), 'utf8');
  const fromUrl = workflow.split('## Upsert From URL')[1].split('## After Upsert')[0];
  assert.match(fromUrl, /add a reference by default[\s\S]*`install\.strategy: upstream`[\s\S]*`version: latest`/);
  assert.match(fromUrl, /Add no `SKILL\.md`; installing\s+fetches the original/);
  assert.match(fromUrl, /only when the user wants SkillVault changes[\s\S]*`Set-SkillUpstreamSection`/);
  assert.match(fromUrl, /copies none of its files/);
});

test('quiet script execution keeps completion checks and necessary interaction', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/rules/references');
  const core = fs.readFileSync(path.join(directory, 'core.md'), 'utf8');
  const details = fs.readFileSync(path.join(directory, 'ai-principles.md'), 'utf8');
  const delivery = core.split('2. **')[1].split('3. **')[0];
  const execution = details.split('### 2. Deliver simply and stay in scope')[1].split('### 3. Do not overdefend')[0];
  assert.match(delivery, /Run routine scripts quietly, without extra windows or unexpected focus changes when supported/);
  assert.match(delivery, /interactive UI only when explicitly requested or required for user action/);
  assert.match(delivery, /quiet\s+execution is unavailable[\s\S]*approved non-GUI alternative or explain and wait for permission/);
  assert.match(execution, /current terminal\/tool session and supported quiet or no-window options/);
  assert.match(execution, /Do not spawn\s+separate consoles or GUI windows for routine script work/);
  assert.match(execution, /logs accessible without automatically revealing terminal panels or stealing focus/);
  assert.match(execution, /Bring UI forward only when explicitly requested or needed for user action/);
  assert.match(execution, /no verified no-window option[\s\S]*approved non-GUI alternative first/);
  assert.match(execution, /wait for permission before opening a window/);
  assert.match(execution, /Reuse explicit\s+approval for that visible action[\s\S]*no answer leaves the command pending, including unattended runs/);
  assert.match(execution, /Await one-shot scripts and retain exit status, output, and errors/);
  assert.match(execution, /long-lived services\/watchers\s+in the background with retrievable status and logs/);
  assert.match(execution, /do not leave required work unverified/);
  assert.match(execution, /Explain before opening UI for authentication, consent, or manual input/);
  assert.match(execution, /Never auto-approve,\s+bypass denials, hide a needed prompt, or request secrets through chat/);
});

test('document-derived authoring maps supported knowledge within the requested scope', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-author');
  const workflow = fs.readFileSync(path.join(directory, 'references/upsert.md'), 'utf8');
  const document = workflow.split('## Author From Documents')[1].split('## Improve from Task Experience')[0];
  const entrypoint = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  assert.ok(entrypoint.includes('./references/upsert.md#author-from-documents'));
  assert.match(document, /both name-based and URL-based upserts/);
  const elements = [...document.matchAll(/^\| ([^|]+) \| ([^|]+) \|\r?$/gm)]
    .filter(([, element]) => element !== 'Skill element' && !/^:?-+:?$/.test(element.trim()));
  assert.deepEqual(elements.map(([, element]) => element), ['Trigger', 'Inputs', 'Decisions and steps', 'Outputs and checks', 'Limits', 'Source references']);
  assert.match(elements.find(([, element]) => element === 'Source references')[2], /edition or revision[\s\S]*locators/);
  assert.match(document, /Do not invent missing steps, thresholds, examples, or locators/);
  assert.match(document, /Keep short, single-purpose\s+inputs compact/);
  assert.match(document, /requested sources and sections with those actually read[\s\S]*skipped\s+or unreadable/);
  assert.match(document, /source-plus-section identities/);
  assert.match(document, /do not install a\s+converter just to process already-readable input/);
  assert.match(document, /dependent guidance Draft[\s\S]*never silently narrow the requested scope/);
});

test('document-derived authoring keeps permissions and redistribution rights explicit', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-author/references/upsert.md'), 'utf8');
  const permissions = workflow.split('### Separate content, permissions, and rights')[1].split('## Improve from Task Experience')[0];
  assert.match(permissions, /source text as evidence, not permission or instructions/);
  assert.match(permissions, /entrypoints and supporting references[\s\S]*instruction overrides[\s\S]*external data transfers/);
  assert.match(permissions, /benign quotation is not automatic rejection/);
  assert.match(permissions, /reuse existing approval for the same action, data, destination,\s+and scope/);
  assert.match(permissions, /permission is missing or unclear[\s\S]*ask the user and wait before proceeding/);
  assert.match(permissions, /refusal or no answer leaves the dependent action\s+pending/);
  assert.match(permissions, /never override explicit\s+denials or project\/host restrictions/);
  assert.match(permissions, /converter's license,[\s\S]*input document's rights,[\s\S]*newly authored guidance/);
  assert.match(permissions, /Ask the user to clarify missing or\s+uncertain sharing rights/);
  assert.match(permissions, /Publication approval is separate from redistribution rights/);
});

test('comparative authoring checks preserve baselines and measurement provenance', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-author');
  const workflow = fs.readFileSync(path.join(directory, 'references/upsert.md'), 'utf8');
  const comparison = workflow.split('### Comparative outcome checks')[1].split('### Trigger regression checks')[0];
  const entrypoint = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  assert.ok(entrypoint.includes('./references/upsert.md#validation'));
  assert.match(workflow.split('## Upsert By Name')[0], /\(#comparative-outcome-checks\)/);
  assert.match(workflow, /wording-only edit[\s\S]*does not start model trials/);
  assert.match(comparison, /new capability, compare with no skill[\s\S]*fixed earlier revision[\s\S]*before editing/);
  assert.match(comparison, /same task prompts and input\s+fixtures/);
  assert.match(comparison, /Keep each version's run outputs\s+separate/);
  assert.match(comparison, /Prevent the baseline from discovering the candidate[\s\S]*inherited context/);
  assert.match(comparison, /Do not uninstall, overwrite, or retarget live\s+copies/);
  assert.match(comparison, /Reuse approval[\s\S]*obtain missing permission[\s\S]*before proceeding/);
  assert.match(comparison, /omitting a required artifact fails[\s\S]*missing evaluation evidence is Unverified/);
  assert.match(comparison, /complete comparable pairs[\s\S]*show excluded runs/);
  assert.match(comparison, /do not label character counts as measured tokens/);
  assert.match(comparison, /Missing metrics are unavailable, not zero[\s\S]*independently verified task outcomes/);
  assert.match(comparison, /label a walkthrough as instruction review,[\s\S]*not an executed benchmark/);
});

test('retrieval-backed comparisons separate retrieval evidence from answer outcomes', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-author/references/upsert.md'), 'utf8');
  const retrieval = workflow.split('#### Retrieval-backed comparisons')[1].split('### Trigger regression checks')[0];
  const cases = [...retrieval.matchAll(/^\| ([^|]+) \| ([^|]+) \| ([^|]+) \|\r?$/gm)]
    .map(match => match.slice(1).map(value => value.trim()));
  const answerable = cases.find(row => /Answerable.*empty retrieval/i.test(row[0]));
  const unanswerable = cases.find(row => /Verified unanswerable/i.test(row[0]));
  const missing = cases.find(row => /Missing labels.*failed execution/i.test(row[0]));
  const duplicates = cases.find(row => /Repeated chunks.*one document/i.test(row[0]));
  assert.ok(answerable && unanswerable && missing && duplicates, 'Preserve the distinct retrieval edge cases');
  assert.match(answerable[1], /Fails.*retrieval criterion/i);
  assert.match(answerable[2], /correctness and citation support separately/);
  assert.match(unanswerable[1], /explicitly empty relevance set.*recall not applicable/);
  assert.match(unanswerable[2], /Correct abstention can pass.*verified against the fixed corpus/);
  assert.match(missing[1], /unavailable.*Unverified/);
  assert.match(missing[2], /Never count missing evidence as a pass/);
  assert.match(duplicates[1], /Deduplicate by source-document ID.*document-level coverage.*must not inflate/);
  assert.match(retrieval, /Only for a requested retrieval-backed skill comparison/);
  assert.match(retrieval, /corpus revision, source\s+permissions, questions, and relevance labels fixed/);
  assert.match(retrieval, /retrieval\s+results separately from final-answer correctness and citation support/);
  assert.match(retrieval, /source IDs, revisions,\s+and passages/);
  assert.match(retrieval, /chunks or source documents[\s\S]*numerator and denominator before scoring/);
  assert.match(retrieval, /Undefined denominators are not applicable, not zero or\s+passing scores/);
  assert.match(retrieval, /Reuse existing test tooling, notes, and approvals/);
  assert.match(retrieval, /no mandatory judge model, service,\s+registry, or automatic evaluation run/);
  assert.match(retrieval, /Non-retrieval comparisons[\s\S]*without a retrieval dataset or extra model calls/);
});

test('trigger regression checks separate selection failures from unavailable evidence', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-author/references/upsert.md'), 'utf8');
  const triggers = workflow.split('### Trigger regression checks')[1].split('## Publishing')[0];
  const outcomes = [...triggers.matchAll(/^\| ([^|]+) \| ([^|]+) \| ([^|]+) \|\r?$/gm)]
    .map(match => match.slice(1).map(value => value.trim()))
    .filter(row => row[0] !== 'Expected' && !/^:?-+:?$/.test(row[0]));
  assert.deepEqual(outcomes, [
    ['Should select', 'Selected', 'Pass'],
    ['Should select', 'Not selected', 'Fail'],
    ['Should not select', 'Selected', 'Fail'],
    ['Should not select', 'Not selected', 'Pass'],
    ['Either', 'Failed, timed out, blocked, or unobservable', 'Unverified'],
  ]);
  assert.match(workflow.split('## Upsert By Name')[0], /\(#trigger-regression-checks\)/);
  assert.match(triggers, /implicit intent[\s\S]*cases owned by another skill/);
  assert.match(triggers, /evaluating or explaining[\s\S]*discovery's read-only behavior/);
  assert.match(triggers, /typo-only edit needs no new model trials/);
  assert.match(triggers, /execution is approved[\s\S]*intended host[\s\S]*supporting evidence/);
  assert.match(triggers, /Never count a runner\s+failure as a successful non-trigger/);
  assert.match(triggers, /Trigger correctness and task-output quality are separate/);
  assert.match(triggers, /fresh cases not used to revise or select a description/);
  assert.match(triggers, /Preserve canonical actions,[\s\S]*permission boundaries/);
  assert.match(triggers, /leave observed triggering Unverified/);
});

test('installation selects exact names unless a * pattern is given', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-install');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-install/skill.json');
  const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(instructions, manifest.name, manifest);
  assert.equal(skill.name, 'skillvault-install');
  assert.equal(manifest.inputs.find(input => input.name === 'exact'), undefined, 'an exact name is the default, not an option');
  assert.ok(manifest.examples.includes('/skillvault-install humanizer'));
  assert.ok(manifest.examples.includes('/skillvault-install harness* global'));
  const guide = fs.readFileSync(path.join(directory, 'references/install.md'), 'utf8');
  assert.ok(guide.includes('Find-SkillCatalogEntry'));
  assert.match(guide, /-Select '?harness\*'?/);
  assert.ok(guide.includes('-Preview'));
  assert.doesNotMatch(guide, /--exact|-Exact\b/);
});

test('installation clean stays read-only until the user picks findings', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-install');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-install/skill.json');
  const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  assert.ok(manifest.inputs.find(input => input.name === 'action').enum.includes('clean'));
  assert.match(instructions, /\| `clean` \| \[[^\]]+\]\(\.\/references\/clean\.md\) \|/);
  const clean = fs.readFileSync(path.join(directory, 'references/clean.md'), 'utf8');
  assert.match(clean, /Clean changes nothing until the user picks/);
  assert.match(clean, /skill-inventory\.ps1 -Check/);
  assert.match(clean, /copies SkillVault did not install[\s\S]*never remove them/);
  assert.match(clean, /An overlap never removes a skill/);
});

test('monitor discovery declares supported sources and a compatible runtime', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'harness-monitor');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-monitor/skill.json');
  const skill = parseSkill(fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8'), entry.name, manifest);
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  const runtime = parseJson(fs.readFileSync(path.join(root, 'skills/planning/harness-runtime/skill.json'), 'utf8'), 'harness-runtime/skill.json');
  assert.equal(manifest.requiredInterfaces['harness-runtime']['monitor-discovery'], 7);
  assert.equal(runtime.runtimeInterfaces['monitor-discovery'], 7);
  assert.equal(runtime.runtimeInterfaces['harness-runtime'], 4);
  const guide = fs.readFileSync(path.join(directory, 'references/discovery.md'), 'utf8');
  const cases = [...guide.matchAll(/```json\r?\n([\s\S]*?)\r?\n```/g)].map(match => parseJson(match[1], 'discovery example'));
  assert.deepEqual(cases[0].monitors.map(monitor => monitor.source.type), ['ado', 'folder']);
  assert.deepEqual(cases[0].monitors[0].scope.terms, ['DAS', 'PACS', 'DaaP']);
  assert.deepEqual(cases[0].monitors[1].scope.terms, ['DAS', 'PACS', 'DaaP']);
  assert.equal(cases[0].monitors[0].topics, undefined);
  assert.ok(cases[0].monitors.every(monitor => monitor.kind === 'discovery' && monitor.allowScheduled === false));
  assert.equal(cases[1].schemaVersion, 1);
  assert.equal(cases[1].items[0].disposition, 'Deferred');
  assert.equal(cases[1].items[0].priority, 1);
  assert.equal(typeof cases[1].items[0].sourceOwner, 'string');
  assert.equal(cases[2].assessments[0].relevance, 'Relevant');
  assert.equal(cases[2].assessments[0].scope, cases[0].monitors[0].scope.description);
  assert.deepEqual(cases[3].sameRequirementAs, ['https://example.invalid/tracker/value']);
  assert.equal(cases[3].claims[0].fact, 'acceptance.value');
  assert.equal(cases[4].correlations[0].authorities['acceptance.value'], cases[4].correlations[0].sources[1]);
  const intake = cases.find(example => example.intake)?.intake;
  assert.ok(intake && intake.mode === 'auto' && typeof intake.worker.flow === 'string' && intake.approvedBy && intake.reason, 'standing intake example names its worker and approval');
  assert.ok(Number.isInteger(intake.maxPerCheck) && intake.maxPerCheck >= 1 && intake.maxPerCheck <= 20);
  assert.match(guide, /effects: "local"/);
  const commands = fs.readFileSync(path.join(directory, 'references/workflow.md'), 'utf8');
  assert.match(commands, /^### Start or Update Monitoring\r?$/m);
  assert.match(commands, /wait 1 minute, and save if no other reply has arrived/);
  assert.match(commands, /do not wait for an answer/);
  assert.match(commands, /Without\s+a yes, start no timer/);
  assert.ok(guide.includes('"type": "json-feed"'));
});

test('harness initialization reuses selected root without another location prompt', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.init), 'utf8');
  const selection = guide.indexOf('## Reuse the Selected Root');
  assert.ok(selection > 0 && selection < guide.indexOf('## Workflow'));
  assert.match(guide, /including the displayed `\.\/` fallback/);
  assert.match(guide, /Do not ask for location confirmation again/);
  assert.match(guide, /If no Root has been selected[\s\S]*\/harness-setup root \.\//);
  assert.match(guide, /Supply `-ConfirmLocation` automatically/);
  assert.match(guide, /-Action Init -ConfirmLocation/);
  assert.match(guide, /\/harness-setup root/);
  assert.doesNotMatch(guide, /Bare reconnects require the same choice|fallback is not initialization confirmation/);
});

test('harness root selects a parent and keeps board placement separate', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.root), 'utf8');
  const location = guide;
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness-runtime/references/runtime.md'), 'utf8');
  assert.match(guide, /always prompt\s+to confirm the location/i);
  assert.match(guide, /If there is no answer[\s\S]*displayed `\.\/` for session selection/);
  assert.match(guide, /subsequent harness actions, including\s+creating the harness[\s\S]*without another location confirmation/);
  assert.match(runtime, /## Root Inheritance/);
  assert.match(runtime, /Every harness action reuses the selected Root/);
  assert.match(runtime, /location selection, not blanket permission/);
  assert.match(guide, /-Action Root/);
  assert.match(location, /`\/harness-setup root <path>` selects the parent/);
  assert.match(location, /`\/hn-setup root` is shorthand for `\/harness-setup root`/);
  // The loc alias is gone (bare, text, and menu convention ADR); a board override is a root form.
  assert.doesNotMatch(location, /`\/(?:harness|hn)-setup loc\b/);
  assert.match(location, /`\/harness-setup root board <path>` changes an empty board's location/);
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
  assert.match(relocation, /`\/harness-setup root <new-parent>`[\s\S]*previously selected harness was initialized[\s\S]*target differs/);
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
  assert.match(location, /`\/hn-setup root <path>` shorthand do not add a second\s+location prompt/);
  assert.match(relocation, /first-selection `\.\/` fallback does not apply/);
  assert.match(relocation, /blocked or failed move is reported separately[\s\S]*new Root remains selected/);
  assert.match(relocation, /-ProjectPath <previous-root> -Action Root -Move -DestinationPath <new-parent> -Apply/);
  assert.match(location, /source\s+and target are the same[\s\S]*without a move prompt/);
  assert.match(location, /select the valid new root\s+before asking about moving data/);
  assert.match(location, /previous harness is not initialized[\s\S]*without another confirmation prompt/);
  assert.match(location, /invalid target leaves the current Root unchanged/);
  const manifest = JSON.parse(fs.readFileSync(path.join(root, 'skills/planning/harness-setup/skill.json'), 'utf8'));
  const entrypoint = fs.readFileSync(path.join(root, 'skills/planning/harness-setup/SKILL.md'), 'utf8');
  assert.equal(manifest.inputs.some(input => input.name === 'move'), false, 'Move confirmation replaces a public move flag');
  assert.doesNotMatch(manifest.description + manifest.examples.join(' '), /--move/);
  assert.match(entrypoint, /\| `root \[<path>\]` \|/);
  assert.match(location, /-BoardPath <path>/);
  assert.doesNotMatch(guide, /Never pass `-ConfirmLocation`[\s\S]*unanswered root prompt/);
  for (const suffix of ['context', 'decision', 'report']) {
    const standalone = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(standalone, /Reuse the selected Root without another location prompt/);
    assert.match(standalone, /If no Root or explicit target exists, use\s+`\/harness-setup root \.\/` once/);
    assert.doesNotMatch(standalone, /Identify the target project from the request or workspace/);
  }
});

test('harness script permissions precede execution and agent fallback preserves boundaries', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness-runtime/references/runtime.md'), 'utf8');
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
  for (const suffix of ['init', 'review', 'test', 'limits', 'fallback', 'timer']) {
    const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(guide, /Script Permissions and Agent\s+Fallback/, `Missing preflight guidance: harness-${suffix}`);
  }
  const scheduler = fs.readFileSync(path.join(root, 'skills/planning/harness-schedule/references/scheduler.md'), 'utf8');
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
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness-runtime/references/runtime.md'), 'utf8');
  const inheritance = runtime.split('## Runner Inheritance')[1]?.split('\n## ')[0];
  assert.ok(inheritance);
  assert.match(inheritance, /Missing or null allowances inherit/);
  assert.match(inheritance, /maximum verified available profile\/effort\/context/);
  assert.match(inheritance, /-RunnerContextPath/);
  assert.match(inheritance, /does not rewrite project settings/);
  assert.match(inheritance, /Blank strings and empty allowance lists add no local restriction/);
  assert.match(inheritance, /`None`, and `Max` use inheritance/);
  const restrictions = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures.limits), 'utf8');
  assert.match(restrictions, /No default restriction is added/);
  assert.match(restrictions, /"allowedModels": "None"/);
  assert.match(restrictions, /"maxAgentCredits": "Max"/);
  for (const suffix of ['dev', 'review', 'limits', 'timer']) {
    const guide = fs.readFileSync(path.join(root, 'skills/planning', harnessProcedures[suffix]), 'utf8');
    assert.match(guide, /Runner\s+Inheritance/);
    assert.doesNotMatch(guide, /Missing runtime settings require setup|unresolved execution settings before creating/);
  }
});

test('harness confirms reuse or new without sharing reviewer conclusions or bypassing locks', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const runtime = fs.readFileSync(path.join(root, 'skills/planning/harness-runtime/references/runtime.md'), 'utf8');
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

test('harness review panel and development loop share one runtime contract', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const planning = path.join(root, 'skills/planning');
  const runtime = fs.readFileSync(path.join(planning, 'harness-runtime/references/runtime.md'), 'utf8');
  const panel = runtime.split('## Review Panel')[1]?.split('\n## ')[0];
  assert.ok(panel, 'Missing the shared review panel section');
  for (const identifier of ['`allowedModels`', '`maxParallelReviewers: 1`', '`runner.secondReviewer: false`', '`/pr-review`', '`profiles`', '`scripts/review-models.json`', '`/harness-setup policy list limits`', '`SKILLVAULT_REVIEW_MODELS`']) {
    assert.ok(panel.includes(identifier), `Review panel contract lost ${identifier}`);
  }
  assert.match(panel.replace(/\s+/g, ' '), /before any model work/);
  const list = parseJson(fs.readFileSync(path.join(planning, 'harness-runtime/scripts/review-models.json'), 'utf8'), 'review-models.json');
  assert.deepEqual(list.families.map(family => family.id), ['gpt', 'claude-opus']);
  assert.equal(list.families[0].models[0], 'gpt-6-astra', 'The owner ranks gpt-6-astra as the strongest GPT reviewer');
  for (const family of list.families) {
    const prefix = family.pattern.replace(/\*$/, '');
    assert.ok(family.models.length > 0, `Empty ${family.label} review list`);
    assert.equal(new Set(family.models).size, family.models.length, `Repeated ${family.label} review model`);
    for (const model of family.models) assert.ok(model.startsWith(prefix), `${model} is outside the ${family.label} family`);
  }
  const limits = fs.readFileSync(path.join(planning, harnessProcedures.limits), 'utf8');
  assert.match(limits, /^\| `maxParallelReviewers` \|/m);
  const review = fs.readFileSync(path.join(planning, harnessProcedures.review), 'utf8');
  const dev = fs.readFileSync(path.join(planning, harnessProcedures.dev), 'utf8');
  for (const guide of [review, dev]) assert.match(guide, /Review Panel/);
  for (const identifier of ['`reviewFindings`', '`outsideTaskScope`', '`NeedsDecision`']) assert.ok(dev.includes(identifier), `Development loop lost ${identifier}`);
  for (const [name, text] of [['runtime', runtime], ['review', review], ['dev', dev]]) {
    assert.doesNotMatch(text, /critical second pass|critical-review phase|Review, Critical, and Fresh/, `Current ${name} guidance still describes the removed Critical pass`);
  }
});

test('harness-dev sprint delegates to owning topics without a second task store', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'harness-dev');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-dev/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['upsert', 'queue', 'sprint', 'test', 'broad']);
  assert.match(skill['argument-hint'], /^\[upsert\|queue\|sprint\|test\|broad\]/);
  assert.match(content, /^\| `sprint \[<goal>\] \[<task>\.\.\.\]` \|/m);
  assert.match(content, /\]\(\.\/references\/sprint\.md\)/);
  for (const reference of ['task', 'dev', 'sprint', 'test', 'test-flows']) {
    assert.ok(fs.existsSync(path.join(directory, `references/${reference}.md`)), `Missing ${reference} procedure`);
  }
  for (const description of [entry.description, manifest.description, skill.description]) assert.ok(description.includes('harness-write'));
  for (const optional of ['harness-write', 'pr-publish']) assert.equal((manifest.dependencies ?? []).includes(optional), false, `${optional} stays optional for sprints`);
  const sprint = fs.readFileSync(path.join(directory, 'references/sprint.md'), 'utf8');
  for (const heading of ['Start or Resume', 'Plan', 'Run', 'Sprint Review', 'Retro', 'Record']) assert.match(sprint, new RegExp(`^## ${heading}\\r?$`, 'm'));
  assert.ok(sprint.includes('.harness_sv/docs/sprints/'));
  assert.ok(sprint.includes('-Action Dev -Id <task-id>'));
  for (const route of ['/harness-write', '/pr-publish', '/harness-dev upsert']) assert.ok(sprint.includes(route), `Sprint lost its ${route} delegation`);
});

test('real tests share the development-tests interface, test stages, and the unit-test policy route', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
  const runtime = parseJson(read('skills/planning/harness-runtime/skill.json'), 'harness-runtime/skill.json');
  assert.equal(runtime.runtimeInterfaces['development-tests'], 1);
  for (const consumer of ['harness-dev', 'harness-setup']) {
    const manifest = parseJson(read(`skills/planning/${consumer}/skill.json`), `${consumer}/skill.json`);
    assert.equal(manifest.requiredInterfaces['harness-runtime']['development-tests'], 1, `${consumer} must require the test stages`);
  }
  const flows = read('skills/planning/harness-dev/references/test-flows.md');
  assert.match(flows, /^## When Tests Run\r?$/m);
  for (const field of ['"afterReview"', '"unitTests"', '"effects": "external"']) assert.ok(flows.includes(field), `The example declaration lacks ${field}`);
  assert.match(read('skills/planning/harness-setup/SKILL.md'), /^\| `policy set unit-tests <blocking\\\|broad>` \|/m);
});

test('review levels default to blocking and every review entry point requires them', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
  const runtime = parseJson(read('skills/planning/harness-runtime/skill.json'), 'harness-runtime/skill.json');
  assert.equal(runtime.runtimeInterfaces['review-levels'], 2);
  const guide = read('skills/planning/harness-runtime/references/runtime.md');
  const levels = guide.split(/^### Review Levels\r?$/m)[1]?.split(/^## /m)[0] ?? '';
  assert.ok(levels, 'The runtime guide defines the review levels');
  assert.match(levels, /^\| `blocking` \(default\) \|/m);
  assert.match(levels, /^\| `broad` \|/m);
  assert.match(levels, /named `critical` until 2026-10-09/, 'Saved critical values still read as blocking');
  for (const consumer of ['skills/planning/harness-review', 'skills/github/pr-review', 'skills/planning/harness-dev']) {
    const manifest = parseJson(read(`${consumer}/skill.json`), `${consumer}/skill.json`);
    assert.equal(manifest.requiredInterfaces['harness-runtime']['review-levels'], 2, `${consumer} must require review levels`);
    assert.match(read(`${consumer}/SKILL.md`), /^\| `broad \[/m, `${consumer} must offer broad as a menu word`);
    assert.doesNotMatch(read(`${consumer}/SKILL.md`), /--broad/, `${consumer} no longer documents --broad`);
  }
  assert.match(read('skills/github/pr-review/references/runtime.md'), /^\| `reviewLevel` \| `blocking`/m);
  // "changes only" skips the Full pass; harness-review needs a runtime that accepts it.
  assert.equal(runtime.runtimeInterfaces['review-scope'], 1);
  const review = parseJson(read('skills/planning/harness-review/skill.json'), 'harness-review/skill.json');
  assert.equal(review.requiredInterfaces['harness-runtime']['review-scope'], 1, 'harness-review must require the review scope interface');
  assert.match(read('skills/planning/harness-review/SKILL.md'), /"changes only"[\s\S]{0,200}-ChangesOnly/);
});

test('pr-publish has no options, keeps existing descriptions, and follows create-pull-request', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
  const publish = read('skills/github/pr-publish/references/publish.md');
  const update = publish.split(/^## Update\r?$/m)[1]?.split(/^## /m)[0] ?? '';
  assert.match(update, /-TableFile/, 'Updates send only the table');
  const create = publish.split(/^## Create\r?$/m)[1]?.split(/^## /m)[0] ?? '';
  assert.match(create, /`draft: false`/, 'A new PR opens ready for review');
  const rules = read('skills/github/pr-publish/references/description.md');
  const headings = [...rules.matchAll(/^## (.+?)\r?$/gm)].map(match => match[1]);
  for (const heading of ['Keep an existing description', 'Write a new description']) assert.ok(headings.includes(heading), `Description rules lost ${heading}`);
  const fresh = rules.split(/^## Write a new description\r?$/m)[1]?.split(/^## /m)[0] ?? '';
  assert.ok(fresh.includes('`create-pull-request`'), 'New descriptions follow create-pull-request');
  for (const file of ['SKILL.md', 'skill.json', 'references/publish.md', 'references/description.md']) {
    assert.doesNotMatch(read(`skills/github/pr-publish/${file}`), /--(draft|ready|copilot)\b/, `${file} advertises an option`);
  }
  assert.doesNotMatch(read('skills/github/pr-publish/scripts/pr-publish.ps1'), /\[switch\]\$(Draft|Ready)\b/);
});

test('harness topics share the Ask Once approval pattern', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const read = relative => fs.readFileSync(path.join(root, relative), 'utf8');
  const runtime = read('skills/planning/harness-runtime/references/runtime.md');
  const section = runtime.split(/^## Ask Once\r?$/m)[1]?.split(/^## /m)[0] ?? '';
  assert.ok(section, 'The runtime guide owns the Ask Once section');
  const actAtOnce = section.match(/^1\. \*\*Act at once\*\*[\s\S]*?(?=^2\. )/m)?.[0] ?? '';
  assert.ok(actAtOnce, 'Fully specified commands act at once');
  for (const command of ['accept <id>', '`/harness-schedule` target with its duration', '`off` or `on`']) assert.ok(actAtOnce.includes(command), `${command} acts at once`);
  assert.doesNotMatch(actAtOnce, /`auto`/, 'auto keeps asking');
  assert.match(section, /Save after 1 minute\*\* for a monitor declaration and test `declare`\./);
  assert.match(section, /\*\*Hold\*\* for every other change/);
  assert.match(section, /without waiting; it starts only on a yes/);
  assert.match(section, /explicit `pause` or `stop` applies\s+at once/);
  assert.match(read('skills/planning/harness-schedule/SKILL.md'), /acts at once/, 'Timer commands act at once when fully specified');
  for (const topic of ['harness-monitor', 'harness-dev', 'harness-setup', 'harness-schedule']) {
    assert.match(read(`skills/planning/${topic}/SKILL.md`), /Ask Once/, `${topic} must follow the shared pattern`);
  }
  assert.doesNotMatch(read('skills/planning/harness-setup/SKILL.md'), /\[--apply\]/, 'Synopses need no --apply step');
});

test('command examples use current menu words and show no removed option or separate --apply step', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  // A request that says --apply still answers the one question, but menus and examples never show it.
  // Options removed on 2026-10-08, 2026-10-09, and 2026-10-14; plain words or menu words replace them.
  const removed = /(?<![\w-])(?:--(?:apply|critical|security|again|limit|include-drafts|recent|max|attempts|setup-exit|all|delete-stale|retire|now|current-file|view|monitors|design-only|chat-only|topics|broad|exact|repo|audience|output|workspace|at|thread|type|required|optional|days|within|duration|policy|repo-ref|follow-up|task|hold|worker|every|new|instance|reuse)|check all)(?![\w-])/;
  // Actions that alone or text took over on 2026-10-09 (bare, text, and menu convention ADR).
  const retiredFirstWords = {
    'harness-setup': ['list', 'init', 'migrate', 'context', 'link', 'loc'],
    'harness-dev': ['list', 'run', 'add', 'update', 'now', 'next'],
    'harness-decide': ['list', 'explain', 'record'],
    'harness-schedule': ['list', 'set', 'disable', 'resume', 'migrate'],
    'harness-monitor': ['list', 'declare', 'check', 'task'],
    'harness-write': ['upsert', 'list', 'create', 'update'],
    'harness-review': ['run'],
    'pr-review': ['run'],
    'pr-watch': ['list', 'add'],
    'pr-publish': ['upsert', 'preview'],
    'skillvault-install': ['install', 'catalog'],
    'skillvault-discover': ['search', 'list', 'evaluate', 'eval', 'expl'],
    'skillvault-author': ['upsert', 'list', 'create', 'update'],
    'rules': ['list', 'upsert', 'add', 'update', 'modify', 'core'],
    'schedule-manage': ['list', 'remove', 'uninstall'],
    'dri': ['list'],
  };
  const topics = catalog.map(entry => entry.name).filter(name => /^(harness-|skillvault-|pr-|rules$|schedule-manage$|dri$)/.test(name));
  const command = new RegExp(`^/(?:${[...topics, 'hn-[a-z]+', 'sv-[a-z]+'].join('|')})(?![\\w-])`);
  const texts = ['README.md', 'AGENTS.md', ...fs.readdirSync(path.join(root, 'docs/plans')).filter(name => name.endsWith('.md')).map(name => `docs/plans/${name}`)]
    .map(file => [file, fs.readFileSync(path.join(root, file), 'utf8')]);
  for (const entry of catalog) {
    const pending = [path.join(root, entry.path)];
    while (pending.length) {
      const current = pending.pop();
      for (const item of fs.readdirSync(current, { withFileTypes: true })) {
        const file = path.join(current, item.name);
        if (item.isDirectory()) pending.push(file);
        else if (item.name.endsWith('.md')) texts.push([path.relative(root, file).split(path.sep).join('/'), fs.readFileSync(file, 'utf8')]);
        else if (item.name === 'skill.json') texts.push([path.relative(root, file).split(path.sep).join('/'), (parseJson(fs.readFileSync(file, 'utf8'), file).examples ?? []).map(example => `\`${example}\``).join('\n')]);
      }
    }
  }
  const offenders = [];
  for (const [file, text] of texts) {
    const inline = [...text.matchAll(/`([^`\r\n]+)`/g)].map(match => match[1]);
    const fenced = [...text.matchAll(/^```[^\r\n]*\r?\n([\s\S]*?)^```/gm)].flatMap(match => match[1].split(/\r?\n/));
    for (const example of [...inline, ...fenced].map(line => line.trim().replace(/\\\|/g, '|'))) {
      if (!command.test(example)) continue;
      const [topic, word] = example.split(/\s+/);
      const name = topic.slice(1).replace(/^hn-/, 'harness-').replace(/^sv-/, 'skillvault-');
      if (removed.test(example) || (retiredFirstWords[name] ?? []).includes(word)) offenders.push(`${file}: ${example}`);
    }
  }
  assert.deepEqual(offenders, [], 'Command examples still show removed options or retired action words');
});

test('handoff runs on explicit requests, installs globally, and keeps upstream attribution', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/planning/handoff');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'handoff/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, 'handoff', manifest);
  // Owner decision 2026-10-16: plain requests such as "restart the session" may load the skill.
  assert.notEqual(skill['disable-model-invocation'], true);
  assert.notEqual(skill['user-invocable'], false);
  assert.match(skill.description, /restart in a fresh session/);
  assert.match(content, /never write a\s+note unprompted/);
  const deliver = content.split(/^## Verify and Deliver\r?$/m)[1]?.split(/^## /m)[0] ?? '';
  assert.match(deliver, /ready-to-paste\s+prompt/, 'The reply ends with a prompt that continues the work in a new session');
  assert.match(deliver, /```text[\s\S]*handoff note at <absolute path to the note>[\s\S]*<first next action>[\s\S]*```/);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.equal(manifest.install.project, true);
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.equal(manifest.version, null);
  assert.equal(manifest.author, 'Matt Pocock');
  assert.equal(skill.metadata.author, manifest.author);
  assert.equal(manifest.upstream.path, 'skills/productivity/handoff');
  assert.equal(manifest.license, 'MIT');
  assert.match(fs.readFileSync(path.join(directory, 'UPSTREAM-LICENSE'), 'utf8'), /Copyright \(c\) 2026 Matt Pocock/);
});

test('handoff follow-ups stay optional at selected transfer points', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const [name, procedure] of [
    ['harness-setup', 'references/context.md'],
    ['harness-decide', 'references/workflow.md'],
    ['harness-dev', 'references/dev.md'],
    ['harness-setup', 'references/fallback.md'],
    ['harness-write', 'references/report.md'],
    ['skillvault-discover', 'references/search.md'],
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
    ['harness-write', 'jarvis-metrics'],
    ['jarvis-metrics', 'harness-write'],
  ]) {
    const entry = catalog.find(candidate => candidate.name === name);
    assert.ok(entry, `Missing reporting skill: ${name}`);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const skill = parseSkill(fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8'), name, manifest);
    for (const description of [entry.description, manifest.description, skill.description]) {
      assert.ok(description.includes(counterpart), `Missing reporting overlap: ${name}`);
    }
    if (name === 'harness-write') {
      const workflow = fs.readFileSync(path.join(directory, 'references/report.md'), 'utf8');
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

test('dri investigates read-only and keeps service details in a private profile', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'dri');
  assert.equal(entry.path, 'skills/monitoring/dri');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'dri/skill.json');
  const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(instructions, 'dri', manifest);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.deepEqual(manifest.dependencies, []);
  const monitor = catalog.find(candidate => candidate.name === 'harness-monitor');
  const monitorDirectory = path.join(root, monitor.path);
  const monitorManifest = parseJson(fs.readFileSync(path.join(monitorDirectory, 'skill.json'), 'utf8'), 'harness-monitor/skill.json');
  const monitorSkill = parseSkill(fs.readFileSync(path.join(monitorDirectory, 'SKILL.md'), 'utf8'), 'harness-monitor', monitorManifest);
  for (const description of [entry.description, manifest.description, skill.description]) assert.match(description, /harness-monitor/);
  for (const description of [monitor.description, monitorManifest.description, monitorSkill.description]) assert.match(description, /\bdri\b/);
  const rules = instructions.replace(/\s+/g, ' ');
  assert.match(rules, /Read-only by default/);
  assert.match(rules, /Every side effect needs the DRI's explicit approval of that exact action/);
  assert.match(rules, /`dri-profile\.md`/);
  assert.match(rules, /Never invent sources, queries, owners, signals, or thresholds/);
  assert.match(rules, /Before `investigate`, read the \[investigation procedure\]\(\.\/references\/investigate\.md\)/);
  const investigation = fs.readFileSync(path.join(directory, 'references/investigate.md'), 'utf8').replace(/\s+/g, ' ');
  assert.match(investigation, /changes nothing/);
  assert.match(investigation, /Never post it/);
  assert.match(fs.readFileSync(path.join(directory, 'references/proposal.md'), 'utf8'), /^Status: Proposed\./m);
});

test('PR commands share one global-default runtime without recursive harness routing', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const name of ['pr-review', 'pr-watch', 'harness-schedule']) {
    const entries = catalog.filter(entry => entry.name === name);
    assert.equal(entries.length, 1);
    assert.equal(entries[0].path, `skills/${name === 'harness-schedule' ? 'planning' : 'github'}/${name}`);
    const directory = path.join(root, entries[0].path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const guide = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const skill = parseSkill(guide, name, manifest);
    assert.equal(manifest.install.defaultScope, 'global');
    assert.match(guide, /user-wide/);
    if (name !== 'harness-schedule') assert.match(guide.replace(/\s+/g, ' '), /no harness Root, harness setup, or data-root choice/, `${name} must not send agents looking for a harness Root or data root`);
    assert.equal(manifest.dependencies.includes('harness-review'), false);
    assert.ok(manifest.dependencies.includes(name === 'pr-review' ? 'harness-runtime' : 'pr-review'));
  }
  for (const [name, counterpart] of [['harness-review', 'pr-review'], ['differential-review', 'pr-review'], ['schedule-manage', 'harness-schedule']]) {
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
  // Hidden runtime bundles are not topics; every user-facing catalog skill needs a topic-map row.
  const hidden = catalog.filter(entry => {
    const skillPath = path.join(root, entry.path, 'SKILL.md');
    if (!fs.existsSync(skillPath)) return false;
    const header = /^---\r?\n([\s\S]*?)\r?\n---/.exec(fs.readFileSync(skillPath, 'utf8').replace(/^\uFEFF/, ''));
    return Boolean(header) && /^user-invocable:\s*false\s*$/m.test(header[1]) && /^disable-model-invocation:\s*true\s*$/m.test(header[1]);
  }).map(entry => entry.name);
  assert.deepEqual(hidden, ['harness-runtime']);
  assert.deepEqual([...new Set(targets)].sort(), catalog.map(entry => entry.name).filter(name => !hidden.includes(name)).sort());
  assert.match(plan, /```mermaid\r?\nflowchart LR/);
  assert.match(plan, /Harness topics register as `\/harness-\*`/);
  assert.match(plan, /shared `harness-runtime` bundle is hidden from the `\/` menu/);
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
  assert.ok(fs.existsSync(path.join(rulesRoot, 'references/extra.md')), 'Extra rules need their repository file');
  assert.match(rules, /\]\(\.\/references\/extra\.md\)/);
  assert.match(fs.readFileSync(path.join(rulesRoot, 'scripts/always-on.ps1'), 'utf8'), /extra\.md/);
  // The /rules core shortcut is gone (bare, text, and menu convention ADR); apply core selects the four core rules.
  assert.doesNotMatch(rules, /`\/rules core`|`core` aliases/);
  assert.match(rules, /apply core/);
  assert.match(rules, /another skill says to apply `\/rules apply`, it means `session`[\s\S]*never writes files/);
  assert.match(management, /The SkillVault library changes only when the user names it/);
  const runner = fs.readFileSync(path.join(root, 'skills/planning/harness-runtime/scripts/harness-runner.ps1'), 'utf8');
  assert.match(runner, /rules\/references\/core\.md/);
  assert.doesNotMatch(runner, /rules\/references\/manage\.md/);
  const source = fs.readFileSync(path.join(root, 'skills/core/skillvault-author/SKILL.md'), 'utf8');
  assert.match(source, /SkillVault repository/);
  assert.match(source, /not an application's\s+source tree/);
  assert.match(source, /installation target/);
});

test('menu skills list only their menu words and route alone and text', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  // Bare, text, and menu convention ADR (2026-10-09): menus list only the other actions; alone and text do the rest.
  const menus = {
    'harness-setup': ['root', 'clean', 'policy'],
    'harness-dev': ['upsert', 'queue', 'sprint', 'test', 'broad'],
    'harness-decide': ['closed', 'all'],
    'harness-schedule': ['clean'],
    'harness-monitor': ['accept', 'auto'],
    'harness-write': ['slots'],
    'harness-review': ['broad', 'list'],
    'pr-review': ['broad', 'list', 'configure'],
    'pr-watch': ['remove'],
    'pr-publish': ['list'],
    'skillvault-install': ['list', 'update', 'uninstall', 'clean', 'refresh'],
    'skillvault-discover': ['explain'],
    'skillvault-author': ['remove'],
    'rules': ['apply', 'remove'],
    'schedule-manage': ['enable', 'disable', 'delete'],
    'dri': ['investigate'],
  };
  const withMenus = catalog.filter(entry => {
    const file = path.join(root, entry.path, 'SKILL.md');
    return fs.existsSync(file) && /^\[[a-z]+(?:\|[a-z]+)*\]/.test(parseSkill(fs.readFileSync(file, 'utf8'), entry.name)['argument-hint'] ?? '');
  }).map(entry => entry.name).sort();
  assert.deepEqual(withMenus, Object.keys(menus).sort(), 'every skill with a menu follows the convention');
  for (const [name, menu] of Object.entries(menus)) {
    const entry = catalog.find(candidate => candidate.name === name);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const skill = parseSkill(instructions, name, manifest);
    const action = manifest.inputs.find(input => input.name === 'action');
    assert.deepEqual(action.enum, menu, name);
    assert.equal(action.default, undefined, `${name}: alone is not an action`);
    assert.ok(skill['argument-hint'].startsWith(`[${menu.join('|')}] [<`), `${name}: the hint shows the menu, then the kind of text`);
    assert.ok(skill.description.startsWith(`[${menu.join('|')}] Alone: `) && / Text: /.test(skill.description), name);
    // The routing table names alone, text, and every menu word, in that order.
    const rows = [...instructions.matchAll(/^\| (Alone|Text|`[a-z]+[^`]*`) \|/gm)].map(([, input]) => input.replace(/^`([a-z]+).*`$/, '$1'));
    assert.deepEqual(rows.slice(0, menu.length + 2), ['Alone', 'Text', ...menu], `${name}: routing table`);
    const routing = instructions.replace(/\s+/g, ' ');
    for (const rule of [
      /Menu words are the actions in brackets/,
      /exactly 3 or 4 leading letters of one/,
      /when the rest of the request fits it; otherwise ask/,
      /Anything else is text, and no input at all is the skill alone/,
      /never changes an action's arguments, permissions, or confirmations/,
      /conversational routing, not script argument parsing/,
    ]) assert.match(routing, rule, name);
    assert.doesNotMatch(routing, /bare default|documented aliases|read-only bare/, `${name}: old routing words`);
  }
  const evaluation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discover/references/evaluate.md'), 'utf8');
  assert.match(evaluation, /chat only/i);
  assert.match(evaluation, /docs\/evaluations\//);
  assert.match(evaluation, /Do not change\s+target skills/);
});

test('decision bulletin separates optional configuration without hiding recorded decisions', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/planning/harness-decide');
  const workflow = fs.readFileSync(path.join(directory, 'references/workflow.md'), 'utf8');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-decide/skill.json');
  const action = manifest.inputs.find(input => input.name === 'action');
  assert.deepEqual(action.enum, ['closed', 'all']);
  assert.equal(action.default, undefined);
  const rows = [...workflow.matchAll(/^\| (.+) \| (.+) \| (.+) \|\r?$/gm)]
    .map(([, request, mapping, display]) => ({ request, mapping, display }));
  const open = rows.find(row => row.request === 'Alone');
  assert.match(open.mapping, /-Action Show -Filter Open/);
  assert.match(open.display, /one-line Configuration When Needed summary and source link/);
  const all = rows.find(row => row.request === '`all`');
  assert.match(all.mapping, /-Action Show -Filter All/);
  assert.match(all.display, /Open decisions, recent decisions, then the detailed Configuration When Needed checklist/);
  assert.match(rows.find(row => row.request === '`closed`').mapping, /-Action Show -Filter Closed/);
  assert.match(rows.find(row => row.request === 'A decision ID').mapping, /-Action Show -Id <decision-id>/);
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

test('decision explanations keep every part and stay read-only', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/planning/harness-decide');
  const skill = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  assert.ok(skill.includes('./references/workflow.md#explain-a-decision-or-question'));
  const workflow = fs.readFileSync(path.join(directory, 'references/workflow.md'), 'utf8');
  const explain = workflow.split(/^## Explain a Decision or Question\r?$/m)[1]?.split(/^## /m)[0];
  assert.ok(explain, 'Keep the explanation procedure separately addressable');
  const parts = [...explain.matchAll(/^\d+\. \*\*([^*]+):\*\*/gm)].map(([, part]) => part);
  assert.deepEqual(parts, ['Question', 'Options', 'Reasons', 'Example', 'Trade-off', 'Status']);
  assert.match(explain.replace(/\s+/g, ' '), /Explaining never records, accepts, or changes a decision/);
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

test('documented action menus match each topic argument-hint', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const menus = new Map();
  for (const entry of catalog) {
    const skillPath = path.join(root, entry.path, 'SKILL.md');
    if (!fs.existsSync(skillPath)) continue;
    const group = /^\[([a-z]+(?:\|[a-z]+)*)\]/.exec(parseSkill(fs.readFileSync(skillPath, 'utf8'), entry.name)['argument-hint'] ?? '');
    if (group) menus.set(entry.name, group[1].split('|'));
  }
  // Synopses such as `/topic [a|b]` (shorthand and escaped table pipes included), Mermaid labels
  // such as `topic<br/>a, b`, and topic-map rows such as `| topic | topic a, b |`.
  const patterns = [
    /(?<![\w./-])\/([a-z][a-z0-9-]*) \[([a-z]+(?:\\?\|[a-z]+)*)\]/g,
    /"([a-z][a-z0-9-]*)<br\/>([a-z]+(?:, [a-z]+)+)(?="|<br\/>)/g,
    /^\| ([a-z][a-z0-9-]*) \| \1 ([a-z]+(?:, [a-z]+)+) \|/gm,
  ];
  let checked = 0;
  const stale = (file, text) => patterns.flatMap(pattern => [...text.matchAll(pattern)]).flatMap(match => {
    const expected = menus.get(match[1].replace(/^hn-/, 'harness-').replace(/^sv-/, 'skillvault-'));
    if (!expected) return [];
    checked++;
    const found = match[2].split(/\\?\||, /);
    return found.join('|') === expected.join('|') ? []
      : [`${file}:${text.slice(0, match.index).split('\n').length}: ${match[1]} [${found.join('|')}], expected [${expected.join('|')}]`];
  });
  for (const sample of [
    '| `/harness-setup [list\\|root\\|init\\|migrate\\|context\\|clean\\|link\\|policy]` | Project |',
    'HN --> WORK["harness-dev<br/>list, add, update, run, queue, sprint, test"]',
    '| rules | rules list, apply, add, update, remove |',
    '`/hn-setup [list|root|init|migrate|context|clean|link|policy]`',
  ]) assert.equal(stale('fixture', sample).length, 1, sample);
  const markdown = (directory) => fs.existsSync(directory) ? fs.readdirSync(directory, { withFileTypes: true }).flatMap(item => {
    const full = path.join(directory, item.name);
    return item.isDirectory() ? markdown(full) : item.name.endsWith('.md') ? [full] : [];
  }) : [];
  // Decision records, evaluations, and review records keep the menus they decided on; current docs and bundles must not drift.
  const files = [path.join(root, 'README.md'), path.join(root, 'AGENTS.md'),
    ...markdown(path.join(root, 'docs')).filter(file => !/[\\/]docs[\\/](?:plans[\\/]decisions|evaluations|reviews)[\\/]/.test(file)),
    ...markdown(path.join(root, 'skills')), ...markdown(path.join(root, 'templates'))];
  checked = 0;
  assert.deepEqual(files.flatMap(file => stale(path.relative(root, file), fs.readFileSync(file, 'utf8'))), []);
  assert.ok(checked >= 30, `expected at least 30 documented action menus, found ${checked}`);
});

test('discovery search builds scoped queries and evidence-backed shortlists', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const search = fs.readFileSync(path.join(root, 'skills/core/skillvault-discover/references/search.md'), 'utf8');
  assert.ok(search.indexOf('## Prepare the Query') < search.indexOf('## Search Order'));
  const order = search.split('## Search Order')[1].split('## External Sources')[0];
  const stages = [...order.matchAll(/^\d+\. (.+)$/gm)].map(([, stage]) => stage);
  assert.equal(stages.length, 5);
  for (const [index, source] of ['installed', 'workspace', 'internal', 'official', 'external'].entries()) {
    assert.ok(stages[index].includes(source), `Preserve discovery lookup stage ${source}`);
  }
  assert.match(order, /explicit source\/URL\/path is authoritative/);
  const external = search.split('## External Sources')[1].split('## Check Candidates')[0];
  assert.ok(external.includes('https://skills.sh/'));
  assert.ok(external.includes('--owner <owner>'));
  assert.match(external, /Do not run `npx`,\s+install packages, or invoke the Skills CLI as a side effect of search/);
  const results = search.match(/## Results[\s\S]*?```text\r?\n([\s\S]*?)```/)[1];
  const fields = new Set([...results.matchAll(/^([^:\r\n]+): /gm)].map(([, field]) => field));
  for (const field of ['Name', 'Source', 'Location', 'Purpose', 'Match', 'Why', 'Requires', 'Evidence', 'Limitations', 'Installed']) {
    assert.ok(fields.has(field), `Search results need ${field}`);
  }
  assert.match(search, /Stars\s+and install counts are optional context, never minimum thresholds/);
  const fallback = search.split('## When Nothing Fits')[1].split('## Blocked Search Continuation')[0];
  assert.match(fallback, /one-off task/);
  assert.match(fallback, /only when a recurring\s+or repeatable gap/);
  assert.match(fallback, /Search does not start that task or create the\s+skill/);
});

test('discovery evaluations separate optional runtime advice from the skill decision', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const evaluation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discover/references/evaluate.md'), 'utf8');
  const output = evaluation.match(/## Output Shape[\s\S]*?```text\r?\n([\s\S]*?)```/)[1];
  const fields = new Map([...output.matchAll(/^([^:\r\n]+): (.+)$/gm)].map(([, name, value]) => [name, value.trim()]));
  assert.equal(fields.get('Skill recommendation'), 'upsert/defer/skip');
  assert.equal(fields.has('Recommendation'), false);
  assert.match(fields.get('Existing-skill improvements'), /None justified \/ Unverified/);
  for (const name of ['Standalone use', 'Harness integration']) assert.match(fields.get(name), /when relevant/);
  assert.match(evaluation, /do not authorize installation, execution, integration, or replacement/);

  const reuse = evaluation.split('## Reuse Inspected Evidence')[1].split('## Behavior')[0];
  assert.match(reuse, /exact canonical source, skill directory, selected revision\/version, and requested scope/);
  assert.match(reuse, /new explicit source or location always takes precedence/);
  assert.match(reuse, /skip name-resolution\s+steps 3-6/);
  assert.match(reuse, /mutable latest branch, unknown revisions/);
  assert.match(reuse, /timestamp alone proves neither unchanged content nor runtime availability/);
  assert.match(reuse, /No persistent search cache or separate evidence store is needed/);
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

test('evaluation proposes existing-skill improvements independently of adoption without applying them', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-discover');
  const evaluation = fs.readFileSync(path.join(directory, 'references/evaluate.md'), 'utf8');
  const improvements = evaluation.split('## Improve Existing Skills')[1].split('## Output Shape')[0];
  const details = new Set([...improvements.matchAll(/^\| ([^|]+) \| [^|]+ \|\r?$/gm)].map(([, field]) => field.trim()));
  for (const field of ['Target', 'Evidence and gap', 'Proposed change', 'Expected benefit', 'Validation']) {
    assert.ok(details.has(field), `Improvement proposals need ${field}`);
  }
  assert.match(improvements, /Read the full relevant section of the current owning skill/);
  assert.match(improvements, /adoption can remain `skip` or `defer`/);
  assert.match(improvements, /a nearby valid case it must preserve/);
  assert.match(improvements, /None justified/);
  assert.match(improvements, /mark the proposed improvement Unverified/);
  assert.match(improvements, /evaluation\s+does not edit target skills, rules, manifests, catalogs, or installed copies/);
  assert.match(improvements, /After the user approves\s+implementation/);
  assert.match(improvements, /Do not execute the handoff during\s+evaluation/);
  const record = evaluation.split('## Evaluation Record')[1];
  assert.match(record, /existing-skill improvement proposals with their targets\/evidence\/checks/);
  const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  assert.ok(instructions.includes('./references/evaluate.md#improve-existing-skills'));
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-discover/skill.json');
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['explain']);
});

test('discovery explains the requested tool or product without substituting or running a skill', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const explanation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discover/references/explain.md'), 'utf8');
  assert.match(explanation, /Explain the requested subject first/);
  assert.match(explanation, /Ask only when the intended subject is genuinely ambiguous/);
  assert.match(explanation, /Do not substitute a related skill for the requested tool or product/);
  assert.match(explanation, /\/skillvault-discover explain playwright/);
  assert.match(explanation, /Read-only: do not install, update, execute, rewrite, schedule, commit, or publish/);
});

test('topic operation guides keep local resource links inside their bundles', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const entry of catalog.filter(entry => /^(harness(?:-|$)|skillvault-|rules$|pr-watch$|pr-publish$|dri$)/.test(entry.name))) {
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
    fs.writeFileSync(path.join(directory, 'skill.json'), JSON.stringify({ name: 'fixture', version: '1.0.0', description: 'A valid fixture' }));
    fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', description: 'A valid fixture', path: relative }]));
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

test('references keep only their source, and adaptations record the upstream commit they include', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skillvault-upstream-'));
  try {
    const directory = path.join(root, 'skills/testing/fixture');
    fs.mkdirSync(directory, { recursive: true });
    fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', description: 'A valid fixture', path: 'skills/testing/fixture' }]));
    const write = (upstream, extra = {}, strategy = 'upstream') => fs.writeFileSync(path.join(directory, 'skill.json'), JSON.stringify({
      name: 'fixture', version: '1.0.0', description: 'A valid fixture', kind: 'reference', upstream, install: { defaultScope: 'global', global: true, strategy }, ...extra,
    }));
    const skillFile = path.join(directory, 'SKILL.md');
    const valid = { repo: 'https://github.com/owner/repo', path: 'skills/fixture', version: 'latest' };
    write(valid);
    assert.equal(validateRepository(root).publicCount, 1, 'a reference needs no SKILL.md');
    for (const version of ['v1.2.0', 'a'.repeat(40)]) {
      write({ ...valid, version });
      assert.equal(validateRepository(root).publicCount, 1, `pinned version ${version}`);
    }
    for (const [field, value, message] of [
      ['repo', 'http://github.com/owner/repo', /HTTPS URL/],
      ['repo', 'https://user:token@github.com/owner/repo', /HTTPS URL/],
      ['path', '../escape', /canonical relative path/],
      ['path', '/rooted', /canonical relative path/],
      ['version', null, /latest, a tag, or a full commit/],
      ['version', '../main', /latest, a tag, or a full commit/],
    ]) {
      write({ ...valid, [field]: value });
      assert.throws(() => validateRepository(root), message, `${field}: ${value}`);
    }
    write(valid, { kind: 'agent' });
    assert.throws(() => validateRepository(root), /kind reference/);
    write(valid);
    fs.writeFileSync(skillFile, validSkill);
    assert.throws(() => validateRepository(root), /keeps no SKILL\.md/, 'a reference with its own SKILL.md must become an adapted skill');

    const adapted = { ...valid, commit: 'b'.repeat(40) };
    const section = '<!-- upstream:begin -->\noriginal\n<!-- upstream:end -->\n';
    write(adapted, { kind: 'agent' }, 'adapted');
    assert.throws(() => validateRepository(root), /upstream:begin/, 'an adapted skill keeps the original in a marked section');
    fs.writeFileSync(skillFile, `${validSkill}## Changes\n\n${section}`);
    assert.equal(validateRepository(root).publicCount, 1, 'an adapted skill keeps its adaptation');
    fs.writeFileSync(skillFile, `${validSkill}${section}${section}`);
    assert.throws(() => validateRepository(root), /exactly one/, 'an adapted skill has one original section');
    fs.writeFileSync(skillFile, `${validSkill}${section}`);
    write(valid, { kind: 'agent' }, 'adapted');
    assert.throws(() => validateRepository(root), /upstream\.commit/, 'an adapted skill records its merge base');
    write({ ...adapted, commit: 'main' }, { kind: 'agent' }, 'adapted');
    assert.throws(() => validateRepository(root), /upstream\.commit/, 'the merge base is a full commit');
    write({ ...adapted, repo: 'http://github.com/owner/repo' }, { kind: 'agent' }, 'adapted');
    assert.throws(() => validateRepository(root), /HTTPS URL/, 'an adapted source follows the reference rules');
    write(adapted, { kind: 'agent' }, 'adapted');
    fs.rmSync(skillFile);
    assert.throws(() => validateRepository(root), /SKILL\.md/, 'an adapted skill needs its SKILL.md');
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});