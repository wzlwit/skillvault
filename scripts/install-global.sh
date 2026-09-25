#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: install-global.sh [--force] [--repo-root PATH] [--skills-dir PATH]

Installs the SkillVault bootstrap skills into the global Copilot skills directory.

  --force          Replace existing installs, including pinned or locally modified ones.
  --repo-root PATH SkillVault checkout to install from (default: the parent of this script).
  --skills-dir PATH Global skills directory (default: $HOME/.copilot/skills).
USAGE
}

script_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_root/.." && pwd)"
global_skills_dir="$HOME/.copilot/skills"
force=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --force) force=1 ;;
    --repo-root)
      shift
      [ "$#" -gt 0 ] || { echo "--repo-root requires a path" >&2; exit 2; }
      repo_root="$1"
      ;;
    --skills-dir)
      shift
      [ "$#" -gt 0 ] || { echo "--skills-dir requires a path" >&2; exit 2; }
      global_skills_dir="$1"
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

bootstrap_file="$repo_root/scripts/bootstrap-skills.json"

# name:source-path of installs earlier bootstrap runs created; keep identical to $legacySkillEntries in install-global.ps1.
legacy_skill_entries=(
  "skillvault:skills/public/core/skillvault"
  "sv-sync:skills/public/sv-sync"
  "skillvault-sync:skills/public/skillvault-sync"
  "ai-principles:skills/public/core/ai-principles"
  "rule-update:skills/public/core/rule-update"
)

if ! command -v node >/dev/null 2>&1; then
  echo "SkillVault bootstrap requires Node.js on PATH to read catalog.json and write install metadata." >&2
  exit 1
fi

if [ -L "$repo_root" ] || [ ! -d "$repo_root" ]; then
  echo "SkillVault checkout is not a directory: $repo_root" >&2
  exit 1
fi

if [ -L "$global_skills_dir" ]; then
  echo "Global skills directory is a symbolic link and will not be used: $global_skills_dir" >&2
  exit 1
fi

if [ -e "$global_skills_dir" ] && [ ! -d "$global_skills_dir" ]; then
  echo "Global skills directory is not a directory: $global_skills_dir" >&2
  exit 1
fi

catalog_file="$repo_root/catalog.json"
if [ ! -f "$catalog_file" ]; then
  echo "Missing catalog: $catalog_file" >&2
  exit 1
fi

if command -v pwsh >/dev/null 2>&1; then
  powershell_arguments=(-NoProfile -NonInteractive -File "$script_root/install-global.ps1" -RepoRoot "$repo_root" -GlobalSkillsPath "$global_skills_dir")
  if [ "$force" -eq 1 ]; then powershell_arguments+=(-Force); fi
  exec pwsh "${powershell_arguments[@]}"
fi

sv_temp_dir=""
current_stage=""
current_backup=""
current_target=""

cleanup() {
  if [ -n "$current_stage" ] && [ -d "$current_stage" ]; then
    rm -rf "$current_stage" || true
  fi
  if [ -n "$current_backup" ] && [ -d "$current_backup" ]; then
    if [ -e "$current_target" ]; then
      echo "Inspect the failed target; the previous install is preserved at: $current_backup" >&2
    elif mv "$current_backup" "$current_target" 2>/dev/null; then
      echo "Restored the previous install: $current_target" >&2
    else
      echo "Install failed and the previous install is preserved at: $current_backup" >&2
    fi
  fi
  if [ -n "$sv_temp_dir" ] && [ -d "$sv_temp_dir" ]; then
    rm -rf "$sv_temp_dir" || true
  fi
}
trap cleanup EXIT

sv_temp_dir="$(mktemp -d)"
sv_helper_file="$sv_temp_dir/skillvault-bootstrap.cjs"
cat >"$sv_helper_file" <<'NODE_HELPER'
'use strict';
const fs = require('fs');
const path = require('path');

const CANONICAL_REPO = 'https://github.com/wzlwit/skillvault';
const SOURCE_REPO = 'https://github.com/wzlwit/skillvault.git';
const METADATA_FILE = '.skillvault-install.json';
const INSTALLED_BY = 'skillvault-bootstrap';
const REQUESTED_VERSION = 'latest';

// PowerShell writes install metadata as UTF-8 with a BOM, which JSON.parse rejects.
function readText(file) {
  return fs.readFileSync(file, 'utf8').replace(/^\uFEFF/, '');
}

function readJsonObject(file) {
  try {
    const parsed = JSON.parse(readText(file));
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return null;
    return parsed;
  } catch (error) {
    return null;
  }
}

function lstatOrNull(target) {
  try {
    return fs.lstatSync(target);
  } catch (error) {
    return null;
  }
}

function isCanonicalRepo(value) {
  if (typeof value !== 'string') return false;
  let repo = value.trim().replace(/\/+$/, '');
  if (/\.git$/i.test(repo)) repo = repo.slice(0, -4);
  return repo.toLowerCase() === CANONICAL_REPO;
}

function isManagedInstall(metadata, sourcePath) {
  if (!metadata) return false;
  if (metadata.installedBy !== 'skillvault' && metadata.installedBy !== INSTALLED_BY) return false;
  if (metadata.sourcePath !== sourcePath) return false;
  return isCanonicalRepo(metadata.sourceRepo);
}

function isCurrentInstall(metadata, sourcePath, version) {
  if (!isManagedInstall(metadata, sourcePath)) return false;
  if (metadata.installedBy !== INSTALLED_BY) return false;
  if (metadata.sourceRepo !== SOURCE_REPO) return false;
  if (metadata.scope !== 'global') return false;
  if (metadata.requestedVersion !== REQUESTED_VERSION) return false;
  if (typeof metadata.installedAt !== 'string' || metadata.installedAt.trim() === '') return false;
  return JSON.stringify(metadata.installedVersion) === JSON.stringify(version);
}

function listSkillFiles(dir) {
  const files = [];
  const pending = [''];
  while (pending.length > 0) {
    const relativeDir = pending.pop();
    const absoluteDir = relativeDir === '' ? dir : path.join(dir, relativeDir);
    for (const entry of fs.readdirSync(absoluteDir)) {
      const relativePath = relativeDir === '' ? entry : relativeDir + '/' + entry;
      const stats = fs.lstatSync(path.join(absoluteDir, entry));
      if (stats.isSymbolicLink()) {
        throw new Error('Skill content contains a symbolic link: ' + path.join(dir, relativePath));
      }
      if (stats.isDirectory()) {
        if (entry !== '.git') pending.push(relativePath);
        continue;
      }
      if (!stats.isFile()) {
        throw new Error('Skill content contains an unsupported entry: ' + path.join(dir, relativePath));
      }
      if (relativePath !== METADATA_FILE) files.push(relativePath);
    }
  }
  return files.sort();
}

function isContentEqual(source, target) {
  let sourceFiles;
  let targetFiles;
  try {
    sourceFiles = listSkillFiles(source);
    targetFiles = listSkillFiles(target);
  } catch (error) {
    return false;
  }
  if (sourceFiles.length !== targetFiles.length) return false;
  for (let index = 0; index < sourceFiles.length; index++) {
    if (sourceFiles[index] !== targetFiles[index]) return false;
    const sourceBytes = fs.readFileSync(path.join(source, sourceFiles[index]));
    const targetBytes = fs.readFileSync(path.join(target, targetFiles[index]));
    if (!sourceBytes.equals(targetBytes)) return false;
  }
  return true;
}

function assertRelativeSourcePath(sourcePath, context) {
  if (typeof sourcePath !== 'string' ||
    !/^[A-Za-z0-9._-]+(\/[A-Za-z0-9._-]+)*$/.test(sourcePath) ||
    /(^|\/)\.\.?(\/|$)/.test(sourcePath)) {
    throw new Error(context + ' must be a canonical repository-relative path: ' + String(sourcePath));
  }
}

function run(args) {
  const command = args[0];

  if (command === 'assert-no-runtime') {
    const root = args[1];
    if (!fs.existsSync(root)) return;
    for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
      if (!entry.isDirectory() || entry.name.startsWith('.skillvault-')) continue;
      const manifest = readJsonObject(path.join(root, entry.name, 'skill.json'));
      if (manifest && ['harness', 'harness-init', 'harness-timer', 'pr-review', 'skillvault-refresh', 'skillvault-fresh', 'sv-refresh'].includes(manifest.name)) {
        throw new Error('Deferred: runtime ownership cannot be verified without PowerShell. Use the guarded PowerShell installer; --force does not bypass runtime coordination.');
      }
    }
    return;
  }

  if (command === 'bootstrap-names') {
    const selectionFile = args[1];
    const names = JSON.parse(readText(selectionFile));
    if (!Array.isArray(names) || names.length === 0) {
      throw new Error('Bootstrap selection must be a non-empty JSON array: ' + selectionFile);
    }
    const seen = new Set();
    for (const name of names) {
      if (typeof name !== 'string' || name.length > 64 || !/^[a-z0-9]+(-[a-z0-9]+)*$/.test(name)) {
        throw new Error('Bootstrap selection must contain exact skill names: ' + selectionFile);
      }
      if (seen.has(name)) throw new Error("Duplicate bootstrap skill '" + name + "' in " + selectionFile);
      seen.add(name);
    }
    process.stdout.write(names.join('\n') + '\n');
    return;
  }

  if (command === 'catalog-entry') {
    const catalogFile = args[1];
    const name = args[2];
    const catalog = JSON.parse(readText(catalogFile));
    if (!Array.isArray(catalog)) throw new Error('Catalog must be a JSON array: ' + catalogFile);
    const matches = catalog.filter((entry) => entry && entry.name === name);
    if (matches.length !== 1) {
      throw new Error("Bootstrap skill '" + name + "' was not found exactly once in " + catalogFile);
    }
    assertRelativeSourcePath(matches[0].path, "Catalog path for '" + name + "'");
    const version = matches[0].version === undefined ? null : matches[0].version;
    process.stdout.write(matches[0].path + '\t' + JSON.stringify(version) + '\n');
    return;
  }

  if (command === 'manifest-version') {
    const skillDir = args[1];
    const name = args[2];
    const catalogVersionJson = args[3];
    const manifestPath = path.join(skillDir, 'skill.json');
    const manifest = readJsonObject(manifestPath);
    if (!manifest) throw new Error('Missing or invalid skill manifest: ' + manifestPath);
    if (manifest.name !== name) {
      throw new Error('Skill manifest name mismatch in ' + manifestPath + ": expected '" + name + "', found '" + String(manifest.name) + "'");
    }
    if (!Object.prototype.hasOwnProperty.call(manifest, 'version')) {
      throw new Error('Missing skill manifest version: ' + manifestPath);
    }
    if (manifest.version !== null && (typeof manifest.version !== 'string' || manifest.version.trim() === '')) {
      throw new Error('Invalid skill manifest version in ' + manifestPath + ': expected a non-empty string or null');
    }
    if (!fs.existsSync(path.join(skillDir, 'SKILL.md'))) {
      throw new Error("Missing SKILL.md for skill '" + name + "': " + skillDir);
    }
    const install = manifest.install && typeof manifest.install === 'object' ? manifest.install : {};
    if (install.defaultScope !== 'global') {
      throw new Error("Bootstrap skill '" + name + "' must declare install.defaultScope 'global' but declares '" + String(install.defaultScope) + "'");
    }
    if (JSON.stringify(manifest.version) !== catalogVersionJson) {
      throw new Error("Bootstrap skill '" + name + "' manifest version " + JSON.stringify(manifest.version) + ' does not match catalog version ' + String(catalogVersionJson));
    }
    process.stdout.write(JSON.stringify(manifest.version) + '\n');
    return;
  }

  if (command === 'assert-tree') {
    const dir = args[1];
    if (listSkillFiles(dir).length === 0) throw new Error('Skill source has no installable files: ' + dir);
    return;
  }

  if (command === 'install-state') {
    const targetDir = args[1];
    const sourceDir = args[2];
    const sourcePath = args[3];
    const version = JSON.parse(args[4]);
    const stats = lstatOrNull(targetDir);
    if (!stats) {
      process.stdout.write('absent\n');
      return;
    }
    if (stats.isSymbolicLink()) {
      throw new Error('Bootstrap target is a symbolic link and will not be replaced: ' + targetDir);
    }
    if (!stats.isDirectory()) {
      throw new Error('Bootstrap target is not a directory: ' + targetDir);
    }
    const metadata = readJsonObject(path.join(targetDir, METADATA_FILE));
    if (isCurrentInstall(metadata, sourcePath, version) && isContentEqual(sourceDir, targetDir)) {
      process.stdout.write('current\n');
      return;
    }
    if (!metadata) {
      process.stdout.write('unmanaged\n');
      return;
    }
    if (typeof metadata.requestedVersion === 'string' &&
      metadata.requestedVersion.trim() !== '' &&
      metadata.requestedVersion !== REQUESTED_VERSION) {
      process.stdout.write('pinned\n');
      return;
    }
    if (!isManagedInstall(metadata, sourcePath)) {
      process.stdout.write('unmanaged\n');
      return;
    }
    process.stdout.write('modified\n');
    return;
  }

  if (command === 'legacy-state') {
    const targetDir = args[1];
    const sourcePath = args[2];
    const stats = lstatOrNull(targetDir);
    if (!stats) {
      process.stdout.write('absent\n');
      return;
    }
    if (stats.isSymbolicLink() || !stats.isDirectory()) {
      process.stdout.write('unmanaged\n');
      return;
    }
    const metadata = readJsonObject(path.join(targetDir, METADATA_FILE));
    process.stdout.write((isManagedInstall(metadata, sourcePath) ? 'managed' : 'unmanaged') + '\n');
    return;
  }

  if (command === 'write-metadata') {
    const targetDir = args[1];
    const sourcePath = args[2];
    assertRelativeSourcePath(sourcePath, 'Install metadata sourcePath');
    const metadata = {
      installedBy: INSTALLED_BY,
      sourceRepo: SOURCE_REPO,
      sourcePath: sourcePath,
      scope: 'global',
      requestedVersion: REQUESTED_VERSION,
      installedVersion: JSON.parse(args[3]),
      installedAt: new Date().toISOString()
    };
    fs.writeFileSync(path.join(targetDir, METADATA_FILE), JSON.stringify(metadata, null, 2) + '\n', 'utf8');
    return;
  }

  throw new Error('Unknown helper command: ' + String(command));
}

const rawArgs = process.argv.slice(1);
const separatorIndex = rawArgs.indexOf('--');
try {
  run(separatorIndex >= 0 ? rawArgs.slice(separatorIndex + 1) : rawArgs);
} catch (error) {
  process.stderr.write((error && error.message ? error.message : String(error)) + '\n');
  process.exit(1);
}
NODE_HELPER

sv_node() {
  node "$sv_helper_file" -- "$@"
}

bootstrap_names="$(sv_node bootstrap-names "$bootstrap_file")"
bootstrap_skill_names=()
while IFS= read -r skill_name; do
  bootstrap_skill_names+=("$skill_name")
done <<<"$bootstrap_names"

plan_names=()
plan_source_dirs=()
plan_source_paths=()
plan_versions=()
plan_catalog_versions=()
plan_actions=()
preflight_errors=()

for skill_name in "${bootstrap_skill_names[@]}"; do
  if ! catalog_entry="$(sv_node catalog-entry "$catalog_file" "$skill_name")"; then
    preflight_errors+=("Cannot read catalog entry: $skill_name")
    continue
  fi

  IFS=$'\t' read -r source_path catalog_version <<<"$catalog_entry"
  source_dir="$repo_root/$source_path"

  if [ -L "$source_dir" ] || [ ! -d "$source_dir" ]; then
    preflight_errors+=("Skill source directory not found: $source_dir")
    continue
  fi

  if ! version="$(sv_node manifest-version "$source_dir" "$skill_name" "$catalog_version")"; then
    preflight_errors+=("Cannot validate manifest: $skill_name")
    continue
  fi

  if ! sv_node assert-tree "$source_dir"; then
    preflight_errors+=("Cannot validate source files: $skill_name")
    continue
  fi

  target="$global_skills_dir/$skill_name"
  if ! state="$(sv_node install-state "$target" "$source_dir" "$source_path" "$version")"; then
    preflight_errors+=("Cannot inspect installed skill: $skill_name")
    continue
  fi

  action="install"
  case "$state" in
    absent) ;;
    current) action="skip" ;;
    pinned)
      if [ "$force" -eq 0 ]; then
        preflight_errors+=("Bootstrap skill '$skill_name' is already installed at $target. It is pinned to a specific version. Review it, then re-run with --force to overwrite.")
        continue
      fi
      ;;
    unmanaged)
      if [ "$force" -eq 0 ]; then
        preflight_errors+=("Bootstrap skill '$skill_name' is already installed at $target. This bootstrap does not manage it. Review it, then re-run with --force to overwrite.")
        continue
      fi
      ;;
    *)
      if [ "$force" -eq 0 ]; then
        preflight_errors+=("Bootstrap skill '$skill_name' is already installed at $target. Its installed content differs from the repository source. Review it, then re-run with --force to overwrite.")
        continue
      fi
      ;;
  esac

  plan_names+=("$skill_name")
  plan_source_dirs+=("$source_dir")
  plan_source_paths+=("$source_path")
  plan_versions+=("$version")
  plan_catalog_versions+=("$catalog_version")
  plan_actions+=("$action")
done

if [[ " ${plan_actions[*]} " == *" install "* ]]; then
  sv_node assert-no-runtime "$global_skills_dir"
fi

if [ "${#preflight_errors[@]}" -gt 0 ]; then
  echo "SkillVault bootstrap preflight failed; nothing was installed or removed:" >&2
  for preflight_error in "${preflight_errors[@]}"; do
    echo "$preflight_error" >&2
  done
  exit 1
fi

if [ "${#plan_names[@]}" -gt 0 ]; then
  for index in "${!plan_names[@]}"; do
    skill_name="${plan_names[$index]}"
    source_dir="${plan_source_dirs[$index]}"
    source_path="${plan_source_paths[$index]}"
    version="${plan_versions[$index]}"
    catalog_version="${plan_catalog_versions[$index]}"
    target="$global_skills_dir/$skill_name"

    if [ "${plan_actions[$index]}" = "skip" ]; then
      echo "Already current: $target"
      continue
    fi

    mkdir -p "$global_skills_dir"
    current_target="$target"
    current_backup=""
    current_stage="$(mktemp -d "$global_skills_dir/.skillvault-stage-XXXXXX")"

    cp -R "$source_dir/." "$current_stage/"
    find "$current_stage" -name '.git' -type d -prune -exec rm -rf {} +
    rm -f "$current_stage/.skillvault-install.json"
    sv_node write-metadata "$current_stage" "$source_path" "$version"
    sv_node manifest-version "$current_stage" "$skill_name" "$catalog_version" >/dev/null

    if [ -e "$target" ]; then
      backup="$global_skills_dir/.skillvault-backup-$$-${RANDOM}"
      while [ -e "$backup" ]; do
        backup="$global_skills_dir/.skillvault-backup-$$-${RANDOM}"
      done
      mv "$target" "$backup"
      current_backup="$backup"
    fi

    mv "$current_stage" "$target"
    current_stage=""

    if [ -n "$current_backup" ]; then
      rm -rf "$current_backup"
      current_backup=""
    fi
    current_target=""

    echo "Installed SkillVault bootstrap skill: $target"
  done
fi

for legacy_entry in "${legacy_skill_entries[@]}"; do
  legacy_name="${legacy_entry%%:*}"
  legacy_source_path="${legacy_entry#*:}"
  legacy_path="$global_skills_dir/$legacy_name"
  legacy_state="$(sv_node legacy-state "$legacy_path" "$legacy_source_path")"

  case "$legacy_state" in
    absent) ;;
    managed)
      if [ "$legacy_name" = "skillvault" ] && [ "$force" -eq 0 ]; then
        echo "Preserved renamed installer: $legacy_path. Review it, then re-run with --force to finish migration to skillvault-install."
        continue
      fi
      sv_node assert-no-runtime "$global_skills_dir"
      rm -rf "$legacy_path"
      echo "Removed superseded SkillVault skill: $legacy_path"
      ;;
    *)
      echo "Preserved unmanaged legacy skill: $legacy_path"
      ;;
  esac
done
