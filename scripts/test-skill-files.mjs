import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test from 'node:test';
import { parseJson, parseSkill, resolveInside, validateRepository } from './validate-skill-files.mjs';

const validSkill = '---\nname: fixture\ndescription: A valid fixture\nargument-hint: "[value]"\nmetadata:\n  version: "1.0.0"\n---\n# Fixture\n';

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

test('repository validation catches broken resources and catalog traversal', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'skillvault-syntax-'));
  try {
    const relative = 'skills/public/testing/fixture';
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
    fs.writeFileSync(path.join(root, 'catalog.json'), JSON.stringify([{ name: 'fixture', path: '../escape' }]));
    assert.throws(() => validateRepository(root), /expected skills\/public/);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});