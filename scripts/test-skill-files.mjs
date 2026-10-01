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
  doc: 'harness-doc/references/workflow.md',
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
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-report/references/workflow.md'), 'utf8');
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
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-report/references/workflow.md'), 'utf8');
  const contract = workflow.split('### Editability Acceptance')[1].split('## Dispatch and Upsert')[0];
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
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-report/references/workflow.md'), 'utf8');
  const workbook = workflow.split('### Workbook Acceptance')[1].split('## Dispatch and Upsert')[0];
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
  const topics = ['harness', ...['policy', 'decision', 'dev', 'doc', 'review', 'task', 'link', 'test', 'monitor', 'report', 'timer'].map(suffix => `harness-${suffix}`)];
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

test('harness documentation declares standalone authoring and post-Humanizer validation', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'harness-doc');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'harness-doc/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.path, 'skills/planning/harness-doc');
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['list', 'upsert']);
  assert.deepEqual(manifest.inputs.find(input => input.name === 'audience').enum, ['internal', 'partner', 'public']);
  assert.deepEqual(manifest.dependencies, ['rules', 'humanizer']);
  assert.equal(manifest.requiredInterfaces, undefined);
  assert.match(content, /without requiring\s+an initialized harness/);
  const rootGuide = fs.readFileSync(path.join(root, 'skills/planning/harness/SKILL.md'), 'utf8');
  assert.ok(rootGuide.includes('/harness-doc list|upsert'));
  const workflow = fs.readFileSync(path.join(directory, 'references/workflow.md'), 'utf8');
  const phases = ['## Resolve the request', '## Gather evidence', '## Draft the set', '## Humanizer pass', '## Validate and deliver'];
  const positions = phases.map(phase => workflow.indexOf(phase));
  assert.ok(positions.every((position, index) => position >= 0 && (index === 0 || position > positions[index - 1])));
  assert.match(workflow, /reference-only; fetch and\s+read its authoritative upstream guidance/);
  assert.match(workflow, /Freeze headings and explicit anchors/);
  assert.match(workflow, /Draft \| Files exist, but essential evidence, Humanizer, or required validation is incomplete/);
  const template = fs.readFileSync(path.join(directory, 'references/doc-set.md'), 'utf8');
  const outline = parseJson(/```json\r?\n([\s\S]*?)\r?\n```/.exec(template)[1], 'doc-set outline');
  assert.deepEqual(outline.pages.map(page => page.purpose), ['overview', 'rationale', 'glossary', 'lifecycle', 'onboarding', 'deep-topic', 'troubleshooting']);
  assert.equal(new Set(outline.pages.map(page => page.file)).size, outline.pages.length);
  const decision = catalog.find(candidate => candidate.name === 'architecture-decision-records');
  const decisionManifest = parseJson(fs.readFileSync(path.join(root, decision.path, 'skill.json'), 'utf8'), 'architecture-decision-records/skill.json');
  const decisionSkill = parseSkill(fs.readFileSync(path.join(root, decision.path, 'SKILL.md'), 'utf8'), decision.name, decisionManifest);
  for (const description of [decision.description, decisionManifest.description, decisionSkill.description]) assert.ok(description.includes('harness-doc'));
});

test('paginated document acceptance checks final pages without widening Markdown output', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-doc/references/workflow.md'), 'utf8');
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

test('Humanizer references preserve Chinese specialization and unknown upstream rights', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  for (const [name, counterpart] of [['humanizer', 'humanizer-ch'], ['humanizer-ch', 'humanizer']]) {
    const entry = catalog.find(candidate => candidate.name === name);
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${name}/skill.json`);
    const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const skill = parseSkill(content, name, manifest);
    assert.equal(entry.version, null);
    assert.equal(manifest.kind, 'reference');
    assert.equal(manifest.install.defaultScope, 'global');
    assert.equal(entry.description, manifest.description);
    assert.equal(skill.description, manifest.description);
    assert.ok(skill.description.includes(counterpart));
    assert.match(content, /fetch and read the (?:authoritative )?upstream (?:guidance|instructions)/);
    assert.equal(fs.existsSync(path.join(directory, 'scripts')), false);
    assert.equal(fs.existsSync(path.join(directory, 'agents/openai.yaml')), false);
    if (name === 'humanizer-ch') {
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
    }
  }
});

test('PPT Master reference preserves provenance and unbundled execution boundaries', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'ppt-master');
  assert.equal(entry.path, 'skills/writing/ppt-master');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'ppt-master/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.version, null);
  assert.equal(manifest.kind, 'reference');
  assert.equal(manifest.author, 'Hugo He');
  assert.equal(manifest.license, 'MIT');
  assert.equal(manifest.upstream.repo, 'https://github.com/hugohe3/ppt-master');
  assert.equal(manifest.upstream.path, 'skills/ppt-master');
  assert.equal(manifest.upstream.version, '6.6.0');
  assert.equal(manifest.upstream.license, 'MIT');
  assert.match(manifest.upstream.revision, /^[a-f0-9]{40}$/);
  assert.ok(content.includes(manifest.upstream.revision));
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.equal(fs.existsSync(path.join(directory, 'scripts')), false);
  assert.equal(fs.existsSync(path.join(directory, 'assets')), false);
  assert.match(content, /No upstream scripts,\s+assets, converter, or full workflow are bundled/);
  assert.match(content, /fetch and read the upstream instructions/);
  assert.match(content, /No installation or execution is implied/);
  assert.match(content, /Default charts\/tables are editable shapes/);
  assert.match(content, /eligible metadata and `--native-charts-and-tables`/);
  assert.match(content, /Brand\/Style[\s\S]*remains flat; Layout\/Deck/);
  assert.match(content, /Edit Native PPTX[\s\S]*inherited Master\/Layout objects/);
  assert.match(content, /Source inspection does not certify PowerPoint editing/);
  for (const name of ['harness-report', 'kpi-dashboard']) {
    assert.ok(skill.description.includes(name));
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
  for (const name of ['harness-doc', 'harness-report']) {
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

test('RAG implementation reference preserves provenance and unbundled execution boundaries', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const catalog = parseJson(fs.readFileSync(path.join(root, 'catalog.json'), 'utf8'), 'catalog.json');
  const entry = catalog.find(candidate => candidate.name === 'rag-implementation');
  assert.equal(entry.path, 'skills/data/rag-implementation');
  const directory = path.join(root, entry.path);
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'rag-implementation/skill.json');
  const content = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(content, entry.name, manifest);
  assert.equal(entry.version, null);
  assert.equal(manifest.version, null);
  assert.equal(manifest.kind, 'reference');
  assert.equal(manifest.author, 'Seth Hobson');
  assert.equal(manifest.maintainer, 'wzlwit');
  assert.equal(manifest.license, 'MIT');
  assert.equal(manifest.source.repo, 'skillvault');
  assert.equal(manifest.source.path, entry.path);
  assert.equal(manifest.upstream.repo, 'https://github.com/wshobson/agents');
  assert.equal(manifest.upstream.path, 'plugins/llm-application-dev/skills/rag-implementation');
  assert.equal(manifest.upstream.version, null);
  assert.equal(manifest.upstream.license, 'MIT');
  assert.match(manifest.upstream.revision, /^[a-f0-9]{40}$/);
  assert.equal(entry.description, manifest.description);
  assert.equal(skill.description, manifest.description);
  assert.equal(manifest.install.defaultScope, 'global');
  assert.deepEqual(manifest.dependencies ?? [], []);
  assert.deepEqual(fs.readdirSync(directory).sort(), ['SKILL.md', 'skill.json']);
  for (const resource of ['SKILL.md', 'references/details.md']) {
    assert.ok(content.includes(`/blob/${manifest.upstream.revision}/${manifest.upstream.path}/${resource}`));
  }
  assert.match(content, /fetch and read the upstream instructions/);
  assert.match(content, /No upstream prompts, examples, scripts, provider clients, or RAG runtime are bundled/);
  assert.match(content, /No installation or execution is implied/);
  assert.match(content, /global installation default does not authorize a new installation/);
  assert.match(content, /legacy `langchain\.retrievers` and `langchain\.storage` imports/);
  assert.match(content, /does not guard empty retrieval, empty relevance sets, or empty test sets/);
  assert.match(content, /stable source IDs, revisions, and supporting passages/);
  assert.match(content, /retrieved text as untrusted evidence, not instruction authority/);
  assert.match(content, /adds no harness action, runtime dependency, or automatic ingestion/);
});

test('document evidence distinguishes partial extraction from complete coverage', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const workflow = fs.readFileSync(path.join(root, 'skills/planning/harness-doc/references/workflow.md'), 'utf8');
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

test('experience-driven authoring keeps learning destinations and edit authority separate', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-authoring');
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
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-authoring/skill.json');
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['list', 'upsert', 'remove']);

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
  const directory = path.join(root, 'skills/core/skillvault-authoring');
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
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-authoring/references/upsert.md'), 'utf8');
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
  const directory = path.join(root, 'skills/core/skillvault-authoring');
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
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-authoring/references/upsert.md'), 'utf8');
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
  const workflow = fs.readFileSync(path.join(root, 'skills/core/skillvault-authoring/references/upsert.md'), 'utf8');
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

test('installation metadata supports partial selection and explicit exact names', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const directory = path.join(root, 'skills/core/skillvault-installation');
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-installation/skill.json');
  const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
  const skill = parseSkill(instructions, manifest.name, manifest);
  assert.equal(skill.name, 'skillvault-installation');
  const exact = manifest.inputs.find(input => input.name === 'exact');
  assert.equal(exact.type, 'boolean');
  assert.equal(exact.default, false);
  assert.ok(manifest.examples.includes('/skillvault-installation install harness global'));
  assert.ok(manifest.examples.includes('/skillvault-installation install --exact harness global'));
  const guide = fs.readFileSync(path.join(directory, 'references/install.md'), 'utf8');
  assert.ok(guide.includes('Find-SkillCatalogEntry'));
  assert.ok(guide.includes('-Select harness'));
  assert.ok(guide.includes('-Preview'));
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
  const runtime = parseJson(fs.readFileSync(path.join(root, 'skills/planning/harness/skill.json'), 'utf8'), 'harness/skill.json');
  assert.equal(manifest.requiredInterfaces.harness['monitor-discovery'], 5);
  assert.equal(runtime.runtimeInterfaces['monitor-discovery'], 5);
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
  assert.ok(guide.includes('"type": "json-feed"'));
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
  for (const entry of catalog.filter(entry => /^(harness(?:-|$)|skillvault-|pr-review$|pr-watch$|pr-publish$|rules$|schedule-manager$)/.test(entry.name))) {
    const directory = path.join(root, entry.path);
    const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), `${entry.name}/skill.json`);
    const instructions = fs.readFileSync(path.join(directory, 'SKILL.md'), 'utf8');
    const guide = parseSkill(instructions, entry.name, manifest);
    const action = manifest.inputs.find(input => input.name === 'action');
    assert.equal(action.default, 'list', entry.name);
    assert.deepEqual(action.enum, guide['argument-hint'].match(/^\[([^\]]+)\]/)[1].split('|'), entry.name);
    assert.equal(action.enum.length, new Set(action.enum).size, entry.name);
    const routing = instructions.replace(/\s+/g, ' ');
    for (const rule of [
      /Action matching applies only to the explicit action token/,
      /exact canonical actions and documented aliases take precedence/i,
      /exactly 3 or 4 leading letters (?:only when they match|may select) one canonical action in this topic/,
      /Multiple matches: show choices and ask; no match: show help/,
      /Ambiguous or unknown tokens execute nothing/,
      /Do not prefix-match aliases, skill names, targets, paths, options, or other arguments/,
      /case handling and natural-language routing|Case handling, natural-language routing/,
      /full names in menus and registrations/,
      /read-only bare default/,
      /arguments, permissions, and confirmations (?:stay )?unchanged/,
      /no extra confirmation is required merely for abbreviation|abbreviation adds no confirmation/,
      /conversational routing, not script argument parsing/,
    ]) assert.match(routing, rule, entry.name);
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

test('discovery search builds scoped queries and evidence-backed shortlists', () => {
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
  const search = fs.readFileSync(path.join(root, 'skills/core/skillvault-discovery/references/search.md'), 'utf8');
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
  const evaluation = fs.readFileSync(path.join(root, 'skills/core/skillvault-discovery/references/evaluate.md'), 'utf8');
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
  const directory = path.join(root, 'skills/core/skillvault-discovery');
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
  const manifest = parseJson(fs.readFileSync(path.join(directory, 'skill.json'), 'utf8'), 'skillvault-discovery/skill.json');
  assert.deepEqual(manifest.inputs.find(input => input.name === 'action').enum, ['list', 'search', 'evaluate', 'explain']);
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
  for (const entry of catalog.filter(entry => /^(harness(?:-|$)|skillvault-|rules$|pr-watch$|pr-publish$)/.test(entry.name))) {
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