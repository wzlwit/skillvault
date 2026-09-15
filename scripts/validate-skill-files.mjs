import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseDocument } from 'yaml';

const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const namePattern = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;
const own = (value, key) => Object.prototype.hasOwnProperty.call(value, key);
const textFile = (file) => fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');

function parseYaml(text, label) {
  const document = parseDocument(text, { uniqueKeys: true });
  assert.equal(document.errors.length, 0, `${label}: ${document.errors.map((error) => error.message).join('; ')}`);
  return document.toJS({ maxAliasCount: 100 });
}

export function parseJson(text, label) {
  const clean = text.replace(/^\uFEFF/, '');
  const value = JSON.parse(clean);
  parseYaml(clean, label);
  return value;
}

export function parseSkill(text, expectedName, manifest) {
  const header = /^---\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/.exec(text.replace(/^\uFEFF/, ''));
  assert.ok(header, `${expectedName}: missing frontmatter delimiters`);
  const metadata = parseYaml(header[1], expectedName);
  assert.ok(metadata && typeof metadata === 'object' && !Array.isArray(metadata), `${expectedName}: frontmatter must be a mapping`);
  assert.equal(metadata.name, expectedName, `${expectedName}: frontmatter name mismatch`);
  assert.ok(typeof metadata.description === 'string' && metadata.description.trim() && metadata.description.length <= 1024,
    `${expectedName}: description must contain 1-1024 characters`);
  if (metadata.metadata != null) {
    assert.ok(typeof metadata.metadata === 'object' && !Array.isArray(metadata.metadata), `${expectedName}: metadata must be a mapping`);
    if (manifest && own(metadata.metadata, 'version')) {
      assert.equal(metadata.metadata.version, manifest.version, `${expectedName}: frontmatter version mismatch`);
    }
    assert.ok(!own(metadata.metadata, 'argument-hint'), `${expectedName}: argument-hint belongs at the top level`);
  }
  for (const flag of ['user-invocable', 'disable-model-invocation']) {
    if (own(metadata, flag)) assert.equal(typeof metadata[flag], 'boolean', `${expectedName}: ${flag} must be boolean`);
  }
  return metadata;
}

export function resolveInside(root, relativePath) {
  const resolved = path.resolve(root, relativePath);
  const relative = path.relative(root, resolved);
  assert.ok(relative !== '..' && !relative.startsWith(`..${path.sep}`) && !path.isAbsolute(relative), `Path escapes root: ${relativePath}`);
  return resolved;
}

function checkBundle(directory, name, manifest) {
  assert.ok(namePattern.test(name) && name.length <= 64, `${name}: invalid skill name`);
  assert.ok(!fs.lstatSync(directory).isSymbolicLink(), `${name}: skill directory must not be a symlink`);
  const file = path.join(directory, 'SKILL.md');
  const content = textFile(file);
  parseSkill(content, name, manifest);
  if (manifest) {
    assert.equal(manifest.name, name, `${name}: manifest name mismatch`);
    if (manifest.readme) assert.ok(fs.existsSync(resolveInside(directory, manifest.readme)), `${name}: missing declared readme`);
  }
  const body = content.replace(/```[^\n]*\n[\s\S]*?```/g, '');
  for (const link of body.matchAll(/\]\((\.\.?\/[^)\s]+)\)/g)) {
    const target = decodeURIComponent(link[1].split('#')[0]);
    const resolved = resolveInside(directory, target);
    assert.ok(fs.existsSync(resolved), `${name}: missing linked file ${target}`);
    resolveInside(fs.realpathSync(directory), fs.realpathSync(resolved));
  }
}

export function validateRepository(root) {
  const catalog = parseJson(textFile(path.join(root, 'catalog.json')), 'catalog.json');
  assert.ok(Array.isArray(catalog), 'catalog.json must be an array');
  const paths = new Set();
  for (const entry of catalog) {
    assert.ok(entry && typeof entry.path === 'string' && typeof entry.name === 'string', 'Catalog entry needs a name and path');
    const parts = entry.path.split('/');
    assert.ok(parts.length === 4 && parts[0] === 'skills' && parts[1] === 'public' && namePattern.test(parts[2]) && parts[3] === entry.name,
      `${entry.name}: expected skills/public/<category>/<name>`);
    assert.ok(!paths.has(entry.path), `${entry.name}: duplicate catalog path`);
    paths.add(entry.path);
    const directory = resolveInside(root, entry.path);
    resolveInside(fs.realpathSync(path.join(root, 'skills/public')), fs.realpathSync(directory));
    const manifest = parseJson(textFile(path.join(directory, 'skill.json')), `${entry.path}/skill.json`);
    checkBundle(directory, entry.name, manifest);
  }

  let installedCount = 0;
  const installedRoot = path.join(root, '.github/skills');
  if (fs.existsSync(installedRoot)) {
    for (const entry of fs.readdirSync(installedRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      if (entry.name.startsWith('.skillvault-stage-') || entry.name.startsWith('.skillvault-backup-')) continue;
      const directory = path.join(installedRoot, entry.name);
      if (!fs.existsSync(path.join(directory, 'SKILL.md'))) continue;
      const manifestPath = path.join(directory, 'skill.json');
      const manifest = fs.existsSync(manifestPath) ? parseJson(textFile(manifestPath), manifestPath) : undefined;
      checkBundle(directory, entry.name, manifest);
      const metadataPath = path.join(directory, '.skillvault-install.json');
      if (fs.existsSync(metadataPath)) parseJson(textFile(metadataPath), metadataPath);
      installedCount++;
    }
  }
  const templatesRoot = path.join(root, 'skills/templates');
  if (fs.existsSync(templatesRoot)) {
    for (const entry of fs.readdirSync(templatesRoot, { withFileTypes: true })) {
      if (!entry.isDirectory()) continue;
      const manifestPath = path.join(templatesRoot, entry.name, 'skill.json');
      if (fs.existsSync(manifestPath)) parseJson(textFile(manifestPath), manifestPath);
    }
  }
  return { publicCount: catalog.length, installedCount };
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    assert.ok(process.argv.length === 2 || (process.argv.length === 4 && process.argv[2] === '--repo'), 'Usage: node validate-skill-files.mjs [--repo <path>]');
    const counts = validateRepository(path.resolve(process.argv[3] ?? repositoryRoot));
    console.log(`Validated YAML, JSON keys, and resource links for ${counts.publicCount} public and ${counts.installedCount} installed skill(s).`);
  } catch (error) {
    console.error(error.message);
    process.exitCode = 1;
  }
}