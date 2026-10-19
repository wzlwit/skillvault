#!/usr/bin/env python3
"""Check the translations of a Power BI project: model captions in TMDL culture files and .resx resource files.

Usage:
    python check_translations.py [--model <X.SemanticModel>] [--resx <folder>] [--base <culture>]
        [--allow-pending] [--names-are-keys] [--text-table <table>]
        [--baseline-model <folder>] [--baseline-resx <folder>] [--details] [--json]

--model is a semantic model folder: the one that holds definition/, or definition/ itself. --resx is the folder that
holds the resource files, named <set>.resx (neutral) and <set>.<culture>.resx. The base culture comes from --base,
else the model's culture property, else the neutral file. The script only reads files. It prints coverage and
findings; exit code 1 when a finding is an error, 2 for bad arguments. Python 3.10 or later, standard library only.
"""
import argparse
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

KINDS = ("table", "column", "measure", "hierarchy", "level")
PLURAL = {"table": "tables", "column": "columns", "measure": "measures", "hierarchy": "hierarchies", "level": "levels"}
NAME = r"'(?:[^']|'')+'|[^\s'=:.]+"
DECL = re.compile(r"^(?P<kind>[A-Za-z]\w*)\s+(?P<name>" + NAME + r")\s*(?P<rest>=.*)?$")
PROP = re.compile(r"^(?P<prop>[A-Za-z]\w*)\s*(?:(?P<colon>:)\s*(?P<value>.*)|(?P<eq>=)\s*(?P<expr>.*))?$")
REF = re.compile(r"^ref\s+(?:cultureInfo|culture)\s+(?P<name>" + NAME + r")\s*$", re.I)
CULTURE = re.compile(r"^(?:cultureInfo|culture)\s+(?P<name>" + NAME + r")\s*$", re.I)
COLUMN_REF = re.compile(r"^(?P<table>'(?:[^']|'')+'|[^\s'.]+)\.(?P<column>'(?:[^']|'')+'|[^\s'.]+)$")
CULTURE_TOKEN = re.compile(r"^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$")
LETTER = re.compile(r"[^\W\d_]")
SHOWN = 10


def unquote(name):
    if len(name) >= 2 and name[0] == name[-1] == "'":
        return name[1:-1].replace("''", "'")
    return name


def text_value(value):
    """A TMDL text property value: trimmed, and unwrapped from optional double quotes."""
    v = (value or "").strip()
    if len(v) >= 2 and v[0] == v[-1] == '"':
        return v[1:-1].replace('""', '"')
    return v


def finding(findings, severity, check, file, message, items=()):
    findings.append({"severity": severity, "check": check, "file": file, "message": message, "items": list(items)})


# ---------------------------------------------------------------- TMDL

def structural_lines(text):
    """(line number, depth, content, space-indented) for each line that declares an object or a property.

    Skips blank lines, /// descriptions, multi-line expressions (deeper than their object's properties) and blocks
    fenced with ```. Depth is the number of leading tabs; a line indented with spaces only counts the file's smallest
    space indent as one level."""
    lines = text.splitlines()
    sizes = [len(x) - len(x.lstrip(" ")) for x in lines if x[:1] == " " and x.strip()]
    unit = min(sizes) if sizes else 4
    skip_from, fenced = None, False
    for number, raw in enumerate(lines, 1):
        content = raw.strip()
        if fenced:
            fenced = content != "```"
            continue
        if not content or content.startswith("///"):
            continue
        tabs = len(raw) - len(raw.lstrip("\t"))
        spaces = 0 if tabs else len(raw) - len(raw.lstrip(" "))
        depth = tabs or spaces // unit
        if skip_from is not None:
            if depth >= skip_from:
                continue
            skip_from = None
        yield number, depth, content, spaces > 0
        decl = DECL.match(content)
        if decl and decl.group("rest") is not None:
            body = decl.group("rest")[1:].strip()
            if body == "```":
                fenced = True
            elif not body:
                skip_from = depth + 2  # an object's expression sits one level below its properties
            continue
        prop = PROP.match(content)
        if prop and prop.group("eq"):
            body = prop.group("expr").strip()
            if body == "```":
                fenced = True
            elif not body:
                skip_from = depth + 1


def key_label(key, table, parent, name):
    kind = key[0]
    if kind == "table":
        return "table %s" % table
    if kind == "level":
        return "level %s[%s][%s]" % (table, parent, name)
    return "%s %s[%s]" % (kind, table, name)


class Model:
    """The objects, cultures and relationships of one semantic model's TMDL files."""

    def __init__(self):
        self.culture = None
        self.refs = []
        self.objects = {}  # (kind, table, parent, name), casefolded -> display names
        self.hidden = set()
        self.relationships = []
        self.cultures = {}  # casefolded culture -> parsed culture file
        self.findings = []

    def add(self, kind, table, parent, name):
        key = (kind, table.casefold(), parent.casefold(), name.casefold())
        self.objects.setdefault(key, {"kind": kind, "table": table, "parent": parent, "name": name})
        return key

    def visible(self, key):
        kind, table, parent, _ = key
        if key in self.hidden or ("table", table, "", table) in self.hidden:
            return False
        return not (kind == "level" and ("hierarchy", table, "", parent) in self.hidden)

    def label(self, key):
        o = self.objects.get(key)
        return key_label(key, o["table"], o["parent"], o["name"]) if o else key_label(key, *key[1:])

    def table_name(self, name):
        key = ("table", name.casefold(), "", name.casefold())
        return self.objects[key]["name"] if key in self.objects else None


def parse_model_file(model, text):
    for _, depth, content, _ in structural_lines(text):
        if depth == 0:
            ref = REF.match(content)
            if ref:
                model.refs.append(unquote(ref.group("name")))
        elif depth == 1:
            prop = PROP.match(content)
            if prop and prop.group("colon") and prop.group("prop").lower() == "culture":
                model.culture = text_value(prop.group("value"))


def parse_table_file(model, text):
    stack, table = [], None  # stack entries: [depth, kind, name, key]
    for _, depth, content, _ in structural_lines(text):
        while stack and stack[-1][0] >= depth:
            stack.pop()
        decl = DECL.match(content)
        if decl:
            kind, name = decl.group("kind").lower(), unquote(decl.group("name"))
            parent, key = (stack[-1] if stack else None), None
            if kind == "table" and depth == 0:
                table = name
                key = model.add("table", name, "", name)
            elif table and parent and parent[1] == "table" and kind in ("column", "measure", "hierarchy"):
                key = model.add(kind, table, "", name)
            elif table and parent and parent[1] == "hierarchy" and kind == "level":
                key = model.add("level", table, parent[2], name)
            stack.append([depth, kind, name, key])
            continue
        prop = PROP.match(content)
        if prop and stack and stack[-1][3] and stack[-1][0] == depth - 1 and not prop.group("eq") \
                and prop.group("prop").lower() in ("ishidden", "isprivate") \
                and (prop.group("value") or "true").strip().lower() != "false":
            model.hidden.add(stack[-1][3])


def parse_relationships(model, text):
    current = None
    for _, depth, content, _ in structural_lines(text):
        if depth == 0:
            decl = DECL.match(content)
            current = None
            if decl and decl.group("kind").lower() == "relationship":
                current = {"name": unquote(decl.group("name")), "from": None, "to": None, "active": True}
                model.relationships.append(current)
            continue
        prop = PROP.match(content) if current is not None and depth == 1 else None
        if not prop or not prop.group("colon"):
            continue
        name, value = prop.group("prop").lower(), prop.group("value").strip()
        if name in ("fromcolumn", "tocolumn"):
            ref = COLUMN_REF.match(value)
            if ref:
                current[name[:-6]] = (unquote(ref.group("table")), unquote(ref.group("column")))
        elif name == "isactive":
            current["active"] = value.lower() != "false"


def parse_culture_file(text):
    info = {"declared": None, "captions": {}, "labels": {}, "duplicates": [], "linguistic": None, "spaced": False}
    stack, translations, linguistic = [], None, None  # stack entries: [depth, kind, name, key, label]
    for number, depth, content, spaced in structural_lines(text):
        info["spaced"] = info["spaced"] or spaced
        while stack and stack[-1][0] >= depth:
            stack.pop()
        if depth == 0:
            decl = CULTURE.match(content)
            if decl and info["declared"] is None:
                info["declared"] = unquote(decl.group("name"))
            stack.append([0, "culture", None, None, None])
            continue
        prop = PROP.match(content)
        if depth == 1 and prop and prop.group("prop").lower() in ("translations", "linguisticmetadata"):
            if prop.group("prop").lower() == "translations":
                translations = translations or number
            else:
                linguistic = linguistic or number
            stack.append([1, prop.group("prop").lower(), None, None, None])
            continue
        if not any(entry[1] == "translations" for entry in stack):
            continue
        decl = DECL.match(content)
        if decl:
            kind, name = decl.group("kind").lower(), unquote(decl.group("name"))
            parent = stack[-1]
            tables = [entry for entry in stack if entry[1] == "table"]
            key = table = hierarchy = None
            if kind == "table":
                key, table, hierarchy = ("table", name.casefold(), "", name.casefold()), name, ""
            elif kind in ("column", "measure", "hierarchy") and parent[1] == "table":
                key, table, hierarchy = (kind, parent[2].casefold(), "", name.casefold()), parent[2], ""
            elif kind == "level" and parent[1] == "hierarchy" and tables:
                table, hierarchy = tables[-1][2], parent[2]
                key = ("level", table.casefold(), hierarchy.casefold(), name.casefold())
            stack.append([depth, kind, name, key, key_label(key, table, hierarchy, name) if key else None])
            continue
        if prop and prop.group("colon") and prop.group("prop").lower() == "caption" \
                and stack[-1][3] and stack[-1][0] == depth - 1:
            key = stack[-1][3]
            if key in info["captions"]:
                info["duplicates"].append(stack[-1][4])
            info["captions"][key] = text_value(prop.group("value"))
            info["labels"][key] = stack[-1][4]
    if linguistic and translations:
        info["linguistic"] = "before" if linguistic < translations else "after"
    elif linguistic:
        info["linguistic"] = "only"
    return info


def analyze_model(files, errors=()):
    """Build a Model from {relative path: text}, paths like model.tmdl, tables/Sales.tmdl, cultures/fr-FR.tmdl."""
    model = Model()
    for path, message in errors:
        finding(model.findings, "error", "model-unreadable", path, message)
    by_folder = {}
    for path in sorted(files):
        folder, _, name = path.replace("\\", "/").rpartition("/")
        by_folder.setdefault(folder.lower(), []).append((path, name))
    if "model.tmdl" in files:
        parse_model_file(model, files["model.tmdl"])
    elif not errors:
        finding(model.findings, "error", "model-unreadable", "model.tmdl", "no model.tmdl, so the model can't be checked")
    for path, _ in by_folder.get("tables", []):
        parse_table_file(model, files[path])
    if "relationships.tmdl" in files:
        parse_relationships(model, files["relationships.tmdl"])
    for path, name in by_folder.get("cultures", []):
        info = parse_culture_file(files[path])
        stem = name[:-5] if name.lower().endswith(".tmdl") else name
        info.update(name=info["declared"] or stem, path=path)
        if info["declared"] is None:
            finding(model.findings, "error", "culture-unreadable", path, "no cultureInfo declaration on the first level")
        elif info["declared"].casefold() != stem.casefold():
            finding(model.findings, "warning", "culture-name", path,
                    "declares culture %s but the file is named %s" % (info["declared"], name))
        if info["name"].casefold() in model.cultures:
            finding(model.findings, "error", "culture-duplicate", path,
                    "culture %s is also declared in %s" % (info["name"], model.cultures[info["name"].casefold()]["path"]))
            continue
        model.cultures[info["name"].casefold()] = info
    return model


# ---------------------------------------------------------------- resource files

def split_resx_name(filename):
    """("Strings", "fr-FR") for Strings.fr-FR.resx; ("Strings", "") for the neutral Strings.resx."""
    stem = filename[:-5] if filename.lower().endswith(".resx") else filename
    head, dot, tail = stem.rpartition(".")
    if dot and head and CULTURE_TOKEN.match(tail):
        return head, tail
    return stem, ""


def parse_resx(data):
    """({name: value}, [duplicate names]) for the string entries of one .resx file; raises ET.ParseError."""
    root = ET.fromstring(data.encode("utf-8") if isinstance(data, str) else data)
    entries, duplicates = {}, []
    for item in root.findall("data"):
        name = item.get("name")
        if name is None or "type" in item.attrib or "mimetype" in item.attrib:
            continue  # not a string resource
        if name in entries:
            duplicates.append(name)
        entries[name] = item.findtext("value") or ""
    return entries, duplicates


def analyze_resx(files, errors=()):
    """{casefolded set: {"name", "files": {casefolded culture or "": {"file", "culture", "entries", "duplicates"}}}}."""
    sets, findings = {}, []
    for path, message in errors:
        finding(findings, "error", "resx-unreadable", path, message)
    for filename in sorted(files):
        set_name, culture = split_resx_name(filename)
        try:
            entries, duplicates = parse_resx(files[filename])
        except ET.ParseError as error:
            finding(findings, "error", "resx-unreadable", filename, "not well-formed XML: %s" % error)
            continue
        group = sets.setdefault(set_name.casefold(), {"name": set_name, "files": {}})
        group["files"][culture.casefold()] = {"file": filename, "culture": culture or "neutral",
                                              "entries": entries, "duplicates": duplicates}
    return sets, findings


def pick_base(files, base):
    if base and base.casefold() in files:
        return base.casefold()
    return "" if "" in files else None


def language(culture):
    return culture.split("-")[0].casefold() if culture else ""


# ---------------------------------------------------------------- checks

def model_coverage(model):
    out = {}
    order = sorted(model.objects, key=model.label)
    for cf, info in sorted(model.cultures.items()):
        is_base = bool(model.culture) and cf == model.culture.casefold()
        kinds, missing = {k: [0, 0] for k in KINDS}, []
        for key in order:
            if not model.visible(key):
                continue
            kinds[key[0]][1] += 1
            if info["captions"].get(key):
                kinds[key[0]][0] += 1
            elif not is_base:
                missing.append(model.label(key))
        out[info["name"]] = {"file": info["path"], "base": is_base, "translated": sum(v[0] for v in kinds.values()),
                             "translatable": sum(v[1] for v in kinds.values()), "byKind": kinds, "missing": missing}
    return out


def check_model(model, findings):
    names = {info["name"].casefold() for info in model.cultures.values()}
    for ref in model.refs:
        if ref.casefold() not in names:
            finding(findings, "error", "culture-ref", "model.tmdl",
                    "ref cultureInfo %s has no culture file; the model ignores the line, so that language has no "
                    "captions. Restore the file or remove the line" % ref)
    listed = {ref.casefold() for ref in model.refs}
    unlisted = [info["path"] for cf, info in sorted(model.cultures.items()) if cf not in listed]
    if unlisted and len(model.cultures) > 1:
        finding(findings, "info", "culture-ref", "model.tmdl", "culture files without a ref cultureInfo line; they "
                "still load, appended at the end, and Desktop adds the lines on its next save", unlisted)
    for cf, info in sorted(model.cultures.items()):
        path = info["path"]
        unknown = []
        for key, caption_label in info["labels"].items():
            if key in model.objects:
                continue
            others = [k for k in model.objects if k[1:] == key[1:] and k[0] != key[0]]
            unknown.append(caption_label + (" (the model has a %s by that name)" % others[0][0] if others else ""))
        if unknown:
            finding(findings, "error", "culture-unknown-object", path, "translations for objects the model doesn't "
                    "have, usually after a rename or delete; the captions are lost", sorted(unknown))
        if info["duplicates"]:
            finding(findings, "error", "culture-duplicate", path, "objects captioned twice; TMDL rejects a property "
                    "declared twice", sorted(set(info["duplicates"])))
        if model.culture and cf == model.culture.casefold():
            renamed = sorted(model.label(k) for k, v in info["captions"].items()
                             if v and k in model.objects and v != model.objects[k]["name"])
            if renamed:
                finding(findings, "info", "culture-base-captions", path, "base-culture captions that differ from the "
                        "object names; Desktop shows the names and the service shows these captions", renamed)
        if info["linguistic"] == "before":
            finding(findings, "warning", "culture-linguistic", path, "linguisticMetadata comes before translations; "
                    "Microsoft's TMDL example puts translations first, and Desktop has refused files in this order "
                    "(UnknownKeyword). Move translations first or drop the linguistic metadata")
        elif info["linguistic"] == "after":
            finding(findings, "info", "culture-linguistic", path, "linguistic metadata and translations share the "
                    "file in the documented order")
        if info["spaced"]:
            finding(findings, "warning", "culture-indentation", path, "indented with spaces; TMDL's default is one "
                    "tab per level, as Desktop writes it")


def check_resx(sets, base, allow_pending, findings):
    coverage = {}
    for cf in sorted(sets):
        group = sets[cf]
        files = group["files"]
        base_cf = pick_base(files, base)
        if base_cf is None:
            finding(findings, "error", "resx-base-missing", group["name"] + ".*.resx",
                    ("no file for the base culture %s and no neutral %s.resx" % (base, group["name"])) if base else
                    "can't tell which file holds the base culture; pass --base")
            continue
        head = files[base_cf]
        base_entries = head["entries"]
        base_culture = base if base_cf == "" and base else head["culture"]
        if head["duplicates"]:
            finding(findings, "error", "resx-duplicate", head["file"], "keys defined twice",
                    sorted(set(head["duplicates"])))
        empty_base = [k for k, v in base_entries.items() if not v.strip()]
        if empty_base:
            finding(findings, "warning", "resx-empty", head["file"], "keys with no text in the base culture",
                    empty_base)
        others = [c for c in sorted(files) if c != base_cf]
        translated_cultures = [c for c in others if c != ""]
        pending = set()
        if allow_pending and translated_cultures:
            pending = {k for k in base_entries if all(k not in files[c]["entries"] for c in translated_cultures)}
            if pending:
                finding(findings, "info", "resx-pending", head["file"], "keys only in the base culture, waiting for "
                        "the translation round; check that this change added each one", sorted(pending))
        cover = {"baseFile": head["file"], "keys": len(base_entries), "pending": sorted(pending), "cultures": {}}
        for c in others:
            f = files[c]
            entries = f["entries"]
            if f["duplicates"]:
                finding(findings, "error", "resx-duplicate", f["file"], "keys defined twice",
                        sorted(set(f["duplicates"])))
            missing = [k for k in base_entries if k not in entries and k not in pending]
            extra = [k for k in entries if k not in base_entries]
            empty = [k for k in base_entries if k in entries and base_entries[k].strip() and not entries[k].strip()]
            identical = [k for k in base_entries if k in entries and entries[k].strip()
                         and entries[k].strip() == base_entries[k].strip() and LETTER.search(base_entries[k])]
            if missing:
                finding(findings, "error", "resx-missing", f["file"], "keys the base culture has", missing)
            if empty:
                finding(findings, "error", "resx-empty", f["file"], "keys with no text, so viewers would see a blank",
                        empty)
            if extra:
                finding(findings, "warning", "resx-extra", f["file"], "keys the base culture doesn't have (removed "
                        "or renamed there?)", extra)
            done = sum(1 for k in base_entries if entries.get(k, "").strip())
            cover["cultures"][f["culture"]] = {"file": f["file"], "translated": done, "identical": len(identical),
                                              "missing": missing, "empty": empty, "extra": extra}
        compared = [c for c in translated_cultures if language(files[c]["culture"]) != language(base_culture)]
        untranslated = []
        for k, v in base_entries.items():
            present = [files[c]["entries"][k] for c in compared if files[c]["entries"].get(k, "").strip()]
            if present and LETTER.search(v) and all(p.strip() == v.strip() for p in present):
                untranslated.append(k)
        if untranslated:
            finding(findings, "warning", "resx-untranslated", head["file"], "keys whose text equals the base text "
                    "in every other language; not translated yet, or a name that stays the same?", untranslated)
        coverage[group["name"]] = cover
    return coverage


def merged_resx(sets, base):
    """(base values, {culture: (culture name, values)}) across all sets, keys casefolded; the first set wins."""
    base_values, cultures = {}, {}
    for cf in sorted(sets):
        files = sets[cf]["files"]
        base_cf = pick_base(files, base)
        if base_cf is None:
            continue
        for k, v in files[base_cf]["entries"].items():
            base_values.setdefault(k.casefold(), v)
        for c, f in files.items():
            if c not in (base_cf, ""):
                values = cultures.setdefault(c, (f["culture"], {}))[1]
                for k, v in f["entries"].items():
                    values.setdefault(k.casefold(), v)
    return base_values, cultures


def check_names_are_keys(model, sets, base, findings):
    base_values, cultures = merged_resx(sets, base)
    visible = [key for key in sorted(model.objects, key=model.label) if model.visible(key)]
    for c in sorted(cultures):
        (culture, values), info = cultures[c], model.cultures.get(c)
        missing, stale = [], []
        for key in visible:
            if key[3] not in base_values:
                continue
            value = values.get(key[3], "").strip()
            if not value or value == base_values[key[3]].strip():
                continue
            caption = info["captions"].get(key, "") if info else ""
            if not caption:
                missing.append(model.label(key))
            elif caption.strip() != value:
                stale.append("%s: caption %r, resource file %r" % (model.label(key), caption, value))
        if info is None and missing:
            finding(findings, "warning", "caption-missing", "cultures/%s.tmdl" % culture, "no culture file, though the "
                    "resource files translate %d object names; generate it" % len(missing), missing)
            continue
        if missing:
            finding(findings, "warning", "caption-missing", info["path"], "objects whose name the resource files "
                    "translate but that have no caption; regenerate the culture file", missing)
        if stale:
            finding(findings, "warning", "caption-stale", info["path"], "captions that differ from the resource "
                    "files; regenerate the culture file", stale)


def check_text_table(model, table, findings):
    name = model.table_name(table)
    if name is None:
        finding(findings, "error", "text-table", "tables/", "the model has no table %s" % table)
        return
    touching = [r for r in model.relationships
                if any(side and side[0].casefold() == table.casefold() for side in (r["from"], r["to"]))]
    if not touching:
        finding(findings, "error", "text-table", "relationships.tmdl", "no relationship touches %s, so nothing "
                "selects the viewer's row and bound text shows the wrong language. Desktop has dropped this "
                "relationship when the table's columns changed; add it back" % name)
    elif not any(r["active"] for r in touching):
        finding(findings, "error", "text-table", "relationships.tmdl", "only inactive relationships touch %s; an "
                "inactive relationship doesn't filter it" % name, [r["name"] for r in touching])


def check_baseline_model(model, old, text_table, findings):
    for cf, info in sorted(old.cultures.items()):
        new = model.cultures.get(cf)
        if new is None:
            finding(findings, "error", "baseline-culture-lost", info["path"], "the previous version had culture %s; "
                    "this one has no culture file for it" % info["name"])
            continue
        lost = [model.label(k) for k, v in info["captions"].items()
                if v and k in model.objects and model.visible(k) and not new["captions"].get(k)]
        if lost:
            finding(findings, "error", "baseline-caption-lost", new["path"], "captions the previous version had for "
                    "objects that still exist", sorted(lost))
    if text_table:
        t = text_table.casefold()
        gone = [old.label(k) for k in old.objects if k[1] == t and k[0] in ("column", "measure", "table")
                and k not in model.objects]
        if gone:
            finding(findings, "error", "baseline-text-lost", "tables/", "text-table fields the previous version had; "
                    "visuals bound to them go blank", sorted(gone))


def check_baseline_resx(sets, old_sets, base, findings):
    for cf in sorted(old_sets):
        old_files = old_sets[cf]["files"]
        new_files = sets.get(cf, {"files": {}})["files"]
        lost = [f["file"] for c, f in sorted(old_files.items()) if c not in new_files]
        if lost:
            finding(findings, "error", "baseline-resx-lost", old_sets[cf]["name"], "resource files the previous "
                    "version had", lost)
        old_base, new_base = pick_base(old_files, base), pick_base(new_files, base)
        if old_base is not None and new_base is not None:
            new_entries = new_files[new_base]["entries"]
            removed = [k for k in old_files[old_base]["entries"] if k not in new_entries]
            if removed:
                finding(findings, "warning", "baseline-key-removed", new_files[new_base]["file"], "keys removed from "
                        "the base culture; make sure no visual or caption still uses them", removed)


# ---------------------------------------------------------------- input and output

def model_folder(path):
    for candidate in (os.path.join(path, "definition"), path):
        if os.path.isfile(os.path.join(candidate, "model.tmdl")):
            return candidate
    return None


def read_model(path):
    """(definition folder, {relative path: text}, [(path, error)])."""
    root = model_folder(path)
    if root is None:
        return path, {}, [("model.tmdl", "no model.tmdl in %s or its definition folder" % path)]
    names = ["model.tmdl", "relationships.tmdl"]
    for folder in ("tables", "cultures"):
        full = os.path.join(root, folder)
        if os.path.isdir(full):
            names += [folder + "/" + n for n in sorted(os.listdir(full)) if n.lower().endswith(".tmdl")]
    files, errors = {}, []
    for rel in names:
        full = os.path.join(root, *rel.split("/"))
        if not os.path.isfile(full):
            continue
        try:
            with open(full, encoding="utf-8-sig") as fh:
                files[rel] = fh.read()
        except (OSError, UnicodeDecodeError) as error:
            errors.append((rel, "can't read: %s" % error))
    return root, files, errors


def read_resx(folder):
    """({file name: bytes}, [(path, error)]) for the .resx files directly in folder."""
    if not os.path.isdir(folder):
        return {}, [(folder, "no such folder")]
    files, errors = {}, []
    for name in sorted(os.listdir(folder)):
        full = os.path.join(folder, name)
        if name.lower().endswith(".resx") and os.path.isfile(full):
            try:
                with open(full, "rb") as fh:
                    files[name] = fh.read()
            except OSError as error:
                errors.append((name, "can't read: %s" % error))
    if not files and not errors:
        errors.append((folder, "no .resx files in this folder"))
    return files, errors


def run(args):
    findings, report = [], {"model": None, "resx": None}
    model = sets = None
    base = args.base
    if args.model:
        root, files, errors = read_model(args.model)
        model = analyze_model(files, errors)
        findings += model.findings
        base = base or model.culture
        if files:
            check_model(model, findings)
        report["model"] = {"path": root, "baseCulture": model.culture, "cultures": model_coverage(model)}
        if args.text_table:
            check_text_table(model, args.text_table, findings)
        if args.baseline_model:
            _, old_files, old_errors = read_model(args.baseline_model)
            old = analyze_model(old_files, old_errors)
            for f in old.findings:
                finding(findings, f["severity"], f["check"], "baseline " + f["file"], f["message"], f["items"])
            check_baseline_model(model, old, args.text_table, findings)
    if args.resx:
        files, errors = read_resx(args.resx)
        sets, resx_findings = analyze_resx(files, errors)
        findings += resx_findings
        report["resx"] = {"path": args.resx, "baseCulture": base,
                          "sets": check_resx(sets, base, args.allow_pending, findings)}
        if args.baseline_resx:
            old_files, old_errors = read_resx(args.baseline_resx)
            old_sets, old_findings = analyze_resx(old_files, old_errors)
            for f in old_findings:
                finding(findings, f["severity"], f["check"], "baseline " + f["file"], f["message"], f["items"])
            check_baseline_resx(sets, old_sets, base, findings)
    if args.names_are_keys and model is not None and sets is not None:
        check_names_are_keys(model, sets, base, findings)
    order = {"error": 0, "warning": 1, "info": 2}
    findings.sort(key=lambda f: order[f["severity"]])
    report["findings"] = findings
    report["counts"] = {s: sum(1 for f in findings if f["severity"] == s) for s in order}
    return report


def percent(done, total):
    return "%3d%%" % round(100.0 * done / total) if total else "   -"


def print_text(report, details, out=None):
    out = out or sys.stdout

    def items(values):
        shown = values if details else values[:SHOWN]
        for v in shown:
            out.write("           %s\n" % v)
        if len(values) > len(shown):
            out.write("           ... and %d more (--details lists all)\n" % (len(values) - len(shown)))

    m = report["model"]
    if m:
        out.write("Model: %s (base culture %s)\n" % (m["path"], m["baseCulture"] or "not set"))
        if m["cultures"]:
            header = "  %-12s %-15s %s" % ("culture", "captions", "  ".join("%-11s" % PLURAL[k] for k in KINDS))
            out.write(header.rstrip() + "\n")
        else:
            out.write("  no culture files\n")
        for name, c in m["cultures"].items():
            if c["base"]:
                out.write("  %-12s base culture: object names serve as its captions\n" % name)
                continue
            share = "%d/%d %s" % (c["translated"], c["translatable"], percent(c["translated"], c["translatable"]))
            kinds = "  ".join("%-11s" % ("%d/%d" % tuple(c["byKind"][k])) for k in KINDS)
            out.write(("  %-12s %-15s %s" % (name, share, kinds)).rstrip() + "\n")
            if details and c["missing"]:
                items(c["missing"])
    r = report["resx"]
    if r:
        out.write("Resource files: %s (base culture %s)\n" % (r["path"], r["baseCulture"] or "from the neutral file"))
        for name, s in r["sets"].items():
            out.write("  %s: %d keys in %s%s\n" % (name, s["keys"], s["baseFile"],
                                                   ", %d pending" % len(s["pending"]) if s["pending"] else ""))
            for culture, c in s["cultures"].items():
                out.write("    %-12s %d/%d translated, %d equal to the base text\n"
                          % (culture, c["translated"], s["keys"], c["identical"]))
    for f in report["findings"]:
        out.write("%-8s %-24s %s: %s\n" % (f["severity"].upper(), f["check"], f["file"], f["message"]))
        items(f["items"])
    counts = report["counts"]
    out.write("%d error(s), %d warning(s), %d info\n" % (counts["error"], counts["warning"], counts["info"]))


def main(argv=None):
    ap = argparse.ArgumentParser(description="Check Power BI model captions (TMDL culture files) and .resx "
                                             "resource files. Reads files only.")
    ap.add_argument("--model", help="the *.SemanticModel folder, or its definition folder")
    ap.add_argument("--resx", help="the folder holding <set>.resx and <set>.<culture>.resx files")
    ap.add_argument("--base", help="the base culture (default: the model's culture, else the neutral file)")
    ap.add_argument("--allow-pending", action="store_true",
                    help="report keys found only in the base culture as pending, not missing")
    ap.add_argument("--names-are-keys", action="store_true",
                    help="resource keys are object names: compare culture captions with the resource files")
    ap.add_argument("--text-table", help="the report-text table that a relationship must filter")
    ap.add_argument("--baseline-model", help="the previous version's model folder, to find lost translations")
    ap.add_argument("--baseline-resx", help="the previous version's resource folder, to find lost files and keys")
    ap.add_argument("--details", action="store_true", help="list every item, including missing captions")
    ap.add_argument("--json", action="store_true", help="print the result as JSON")
    args = ap.parse_args(argv)
    if not args.model and not args.resx:
        ap.error("give --model, --resx, or both")
    for option, needs, wrong in (("--names-are-keys", "--model and --resx",
                                  args.names_are_keys and not (args.model and args.resx)),
                                 ("--text-table", "--model", args.text_table and not args.model),
                                 ("--baseline-model", "--model", args.baseline_model and not args.model),
                                 ("--baseline-resx", "--resx", args.baseline_resx and not args.resx)):
        if wrong:
            ap.error("%s needs %s" % (option, needs))
    report = run(args)
    if args.json:
        print(json.dumps(report, indent=2, ensure_ascii=True))
    else:
        if hasattr(sys.stdout, "reconfigure"):
            sys.stdout.reconfigure(errors="backslashreplace")
        print_text(report, args.details)
    return 1 if report["counts"]["error"] else 0


if __name__ == "__main__":
    sys.exit(main())
