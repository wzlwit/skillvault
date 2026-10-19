#!/usr/bin/env python3
"""Structural tests for a Power BI report saved in the enhanced report format (PBIR): a .Report folder, a Power BI
project (.pbip), or a Power BI Desktop file (.pbix) that stores its report as PBIR.

Usage:
    python verify_report.py <X.Report | X.pbip | X.pbix> [--model <X.SemanticModel>] [--against <X.Report>]
        [--model-against <X.SemanticModel>] [--checks rules,geometry,bindings,text|none] [--rules <pack.yaml>]
        [--resx <base-language.resx>] [--wireframe <out.html>] [--json] [--strict]

Checks (all by default; --checks picks a subset):
  rules     pbir-utils expression rules: ../rules/generic.yaml always (a range slicer too short for its slider, slicer
            dates out of order, missing alt text, default page names), then a project's own pack from --rules.
  geometry  every shown visual lies inside its page, and no two shown content visuals overlap. Cards may stack on
            cards; a button over content is a warning. Group offsets are applied, since PBIR stores a grouped
            visual's position relative to its group.
  bindings  every table, column and measure that the report, a page or a visual uses exists in the model: the TMDL
            folder of a PBIP or --model, or the model inside a PBIX, read with PBIXRay.
  text      a title or subtitle wider than its visual, a legend name wider than a side legend, and a short titled
            textbox whose paragraph shows a scrollbar. Measured with Windows GDI and skipped elsewhere. Titles bound
            to a text table are measured when --resx gives their base-language text.
Parity, for the PBIX files of a release:
  --against        every Report/definition file of the PBIX equals the PBIR folder's, byte for byte.
  --model-against  every measure of the PBIX's model has the same DAX as the TMDL, whitespace aside (PBIXRay).
A model-only PBIX holds Desktop's empty placeholder page, so check it with --checks none --model-against <folder>.

Only reads: a PBIX is read from a temporary copy, and nothing is written except the --wireframe file. Output: a
line per check, a line per finding (SEVERITY check where: message), then the counts; --json prints the same as JSON.
Exit code 0 when nothing fails; 1 on an error (with --strict, also on a warning); 2 when the input or the arguments
cannot be used. Needs pbir-utils for the rules and the wireframe, and pbixray for a PBIX's model.
"""
import argparse
import contextlib
import glob
import io
import json
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
GENERIC_RULES = os.path.normpath(os.path.join(HERE, "..", "rules", "generic.yaml"))
CHECKS = ("rules", "geometry", "bindings", "text")
DECORATIVE = {"textbox", "shape", "basicShape", "image"}
BUTTONS = {"actionButton", "pageNavigator", "bookmarkNavigator"}
PIE_CHARTS = {"donutChart", "pieChart"}
# Visual types whose title stays off unless the visual turns it on (a button's title often holds an internal name).
TITLE_OFF_BY_DEFAULT = {"actionButton", "shape", "basicShape", "image", "textbox", "slicer", "advancedSlicerVisual",
                        "pageNavigator", "bookmarkNavigator"}
TOLERANCE = 1.0  # px: touching edges and rounding are not overlaps
# Calibrated on one 1280 x 720 report in Segoe UI: a title needs its text width plus 24 px; a legend on the left or
# right gets 30% of the visual's width, minus about 30 px for markers and padding; a titled textbox under 48 px has no
# room for a paragraph under its title and shows a scrollbar. Confirm a text finding with a render.
TITLE_MARGIN, LEGEND_SHARE, LEGEND_MARGIN, TEXTBOX_MIN_HEIGHT = 24, 0.3, 30, 48
NAME = r"('(?:[^']|'')+'|[^\s=']+)"
MEASURE = re.compile(r"^\tmeasure\s+" + NAME + r"\s*=\s*(.*)$")
LEGACY = ("the report is in the legacy format (PBIR-Legacy); open it in a current Power BI Desktop and save it, "
          "which converts it to PBIR")
SEVERITIES = ("error", "warning", "info")

findings = []
summary = {}


def add(check, severity, where, message):
    findings.append({"check": check, "severity": severity, "where": where, "message": message})


def fail(message):
    """Stop because the input or the arguments cannot be used (exit code 2)."""
    print(message, file=sys.stderr)
    raise SystemExit(2)


def load(path):
    try:
        with open(path, encoding="utf-8-sig") as f:
            return json.load(f)
    except ValueError as e:
        fail("%s is not valid JSON: %s" % (path, e))


def read_bytes(path):
    with open(path, "rb") as f:
        return f.read()


def unquote(name):
    return name[1:-1].replace("''", "'") if name.startswith("'") else name


def literal(objects, name, prop):
    """The literal of objects[name][0].properties[prop], such as '1D', 'true' or "'Between'"; None when unset."""
    try:
        return objects[name][0]["properties"][prop]["expr"]["Literal"]["Value"]
    except (KeyError, IndexError, TypeError):
        return None


def number(value, default):
    """The number in a literal such as 11D, 11L or '11' (Desktop writes all three for font sizes)."""
    m = re.search(r"-?\d+(?:\.\d+)?", value or "")
    return float(m.group()) if m else default


# ---------------------------------------------------------------- inputs

def model_from_pbir(report_dir):
    """The TMDL folder a report binds to by path (definition.pbir datasetReference.byPath), if any."""
    pbir = os.path.join(report_dir, "definition.pbir")
    if not os.path.isfile(pbir):
        return None
    rel = load(pbir).get("datasetReference", {}).get("byPath", {}).get("path")
    path = os.path.normpath(os.path.join(report_dir, rel)) if rel else None
    return path if path and os.path.isdir(path) else None


def extract_report(pbix, tmp):
    """Copy the PBIR report inside a PBIX (Report/definition/...) to <tmp>/<name>.Report.
    Returns (folder, False), or (None, True) for a legacy report and (None, False) when there is no report."""
    report_dir = os.path.join(tmp, os.path.splitext(os.path.basename(pbix))[0] + ".Report")
    root = os.path.abspath(report_dir) + os.sep
    with zipfile.ZipFile(pbix) as z:
        names = z.namelist()
        if "Report/definition/report.json" not in names:
            return None, "Report/Layout" in names
        for n in names:
            if not n.startswith("Report/") or n.endswith("/"):
                continue
            dest = os.path.abspath(os.path.join(report_dir, *n[len("Report/"):].split("/")))
            if not dest.startswith(root):
                continue  # a part that would land outside the copy
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                f.write(z.read(n))
    return report_dir, False


def resolve(path, tmp):
    """(report folder, PBIX path or None, TMDL folder or None) for a .Report folder, a .pbip or a .pbix."""
    p = os.path.abspath(path)
    if os.path.isfile(p) and p.lower().endswith(".pbix"):
        try:
            report_dir, legacy = extract_report(p, tmp)
        except zipfile.BadZipFile:
            fail("%s is not a readable PBIX file" % path)
        if report_dir is None:
            fail("%s: %s" % (path, LEGACY if legacy else "no report found in the PBIX"))
        return report_dir, p, None
    if os.path.isfile(p) and p.lower().endswith(".pbip"):
        rel = next((a["report"]["path"] for a in load(p).get("artifacts", []) if "report" in a), None)
        p = os.path.normpath(os.path.join(os.path.dirname(p), rel)) if rel else os.path.splitext(p)[0] + ".Report"
    if not os.path.isfile(os.path.join(p, "definition", "report.json")):
        if os.path.isfile(os.path.join(p, "report.json")):
            fail("%s: %s" % (path, LEGACY))
        fail("%s is not a PBIR report folder, PBIP project or PBIX file" % path)
    return p, None, model_from_pbir(p)


def pages(report_dir):
    """[(page, [visual, ...])] with each visual's absolute position in visual["_abs"] = (x, y, w, h, hidden)."""
    out = []
    for pj in sorted(glob.glob(os.path.join(report_dir, "definition", "pages", "*", "page.json"))):
        page = load(pj)
        visuals = [load(f) for f in sorted(glob.glob(os.path.join(os.path.dirname(pj), "visuals", "*", "visual.json")))]
        by_name = {v.get("name"): v for v in visuals}
        for v in visuals:
            pos = v.get("position", {})
            x, y, hidden = pos.get("x", 0), pos.get("y", 0), bool(v.get("isHidden"))
            parent, seen = v.get("parentGroupName"), set()
            while parent in by_name and parent not in seen:
                seen.add(parent)
                group = by_name[parent]
                x += group.get("position", {}).get("x", 0)
                y += group.get("position", {}).get("y", 0)
                hidden = hidden or bool(group.get("isHidden"))
                parent = group.get("parentGroupName")
            v["_abs"] = (x, y, pos.get("width", 0), pos.get("height", 0), hidden)
        out.append((page, visuals))
    return out


def label(page, v=None):
    name = page.get("displayName") or page.get("name", "?")
    if v is None:
        return name
    return "%s / %s (%s)" % (name, v.get("name", "?"), v.get("visual", {}).get("visualType", "group"))


# ---------------------------------------------------------------- rules and geometry

def check_rules(report_dir, packs):
    """Run each pbir-utils rule pack in packs, a list of (label, path); violations become findings."""
    try:
        import pbir_utils
    except ImportError:
        add("rules", "error", "setup", "pbir-utils is not installed: pip install pbir-utils")
        return
    results = []
    for name, path in packs:
        with contextlib.redirect_stdout(io.StringIO()):
            result = pbir_utils.validate_report(report_dir, source="rules", rules_config=path, strict=False)
        for v in result.violations:
            where = v.get("page_name") or "report"
            if v.get("visual_name"):
                where += " / %s (%s)" % (v["visual_name"], v.get("visual_type", "?"))
            add("rules", v.get("severity", "warning"), where, "%s: %s" % (v.get("rule_id"), v.get("message")))
        results.append("%s %d passed, %d failed" % (name, result.passed, result.failed))
    summary["rules"] = "; ".join(results)


def check_geometry(report_pages):
    n = 0
    for page, visuals in report_pages:
        width, height = page.get("width", 1280), page.get("height", 720)
        shown = [v for v in visuals if not v["_abs"][4]]
        for v in shown:
            n += 1
            x, y, w, h, _ = v["_abs"]
            if x < -TOLERANCE or y < -TOLERANCE or x + w > width + TOLERANCE or y + h > height + TOLERANCE:
                add("geometry", "error", label(page, v), "lies outside the %g x %g page (x %g, y %g, %g x %g)"
                    % (width, height, x, y, w, h))
        content = [v for v in shown if "visual" in v and v["visual"].get("visualType") not in DECORATIVE]
        for i, a in enumerate(content):
            for b in content[i + 1:]:
                ax, ay, aw, ah, _ = a["_abs"]
                bx, by, bw, bh, _ = b["_abs"]
                ow, oh = min(ax + aw, bx + bw) - max(ax, bx), min(ay + ah, by + bh) - max(ay, by)
                if ow <= TOLERANCE or oh <= TOLERANCE:
                    continue
                ta, tb = a["visual"].get("visualType"), b["visual"].get("visualType")
                if ta == tb == "card":
                    continue  # a KPI value and its caption stack on one tile
                severity = "warning" if ta in BUTTONS or tb in BUTTONS else "error"
                add("geometry", severity, label(page, a), "overlaps %s (%s) by %g x %g px"
                    % (b.get("name"), tb, ow, oh))
    summary["geometry"] = "%d shown visuals checked" % n


# ---------------------------------------------------------------- bindings

def field_refs(node, out, aliases=None, parent=None):
    """Add (kind, table, name) for every Column, Measure and Hierarchy reference; filter aliases resolve via From."""
    aliases = aliases or {}
    if isinstance(node, dict):
        if isinstance(node.get("From"), list):
            aliases = dict(aliases, **{f["Name"]: f["Entity"] for f in node["From"]
                                       if isinstance(f, dict) and "Name" in f and "Entity" in f})
        expr = node.get("Expression")
        if parent in ("Column", "Measure", "Hierarchy") and isinstance(expr, dict) and "SourceRef" in expr:
            src = expr["SourceRef"]
            table = src.get("Entity") or aliases.get(src.get("Source"))
            if table:
                out.add((parent, table, node.get("Property") if parent != "Hierarchy" else None))
        for k, v in node.items():
            field_refs(v, out, aliases, k)
    elif isinstance(node, list):
        for item in node:
            field_refs(item, out, aliases, parent)


def report_refs(report_dir):
    """{(kind, table, name): [where, ...]} from report.json, pages and visuals, and the report-level measures."""
    refs, local = {}, set()

    def collect(obj, where):
        found = set()
        field_refs(obj, found)
        for r in found:
            refs.setdefault(r, []).append(where)
    d = os.path.join(report_dir, "definition")
    collect(load(os.path.join(d, "report.json")), "report.json")
    for page, visuals in pages(report_dir):
        collect({k: v for k, v in page.items() if k != "visuals"}, label(page))
        for v in visuals:
            collect({k: x for k, x in v.items() if k != "_abs"}, label(page, v))
    ext = os.path.join(d, "reportExtensions.json")
    if os.path.isfile(ext):
        for entity in load(ext).get("entities", []):
            for m in entity.get("measures", []):
                local.add((entity.get("name"), m.get("name")))
    return refs, local


def tmdl_names(model_dir):
    """(tables, columns, measures) declared in <model>/definition/tables/*.tmdl."""
    tables, columns, measures = set(), set(), set()
    for f in glob.glob(os.path.join(model_dir, "definition", "tables", "*.tmdl")):
        with open(f, encoding="utf-8-sig") as fh:
            text = fh.read()
        t = re.search(r"^table\s+" + NAME, text, re.M)
        if not t:
            continue
        table = unquote(t.group(1))
        tables.add(table)
        columns |= {(table, unquote(c)) for c in re.findall(r"^\tcolumn\s+" + NAME, text, re.M)}
        measures |= {(table, unquote(m)) for m in re.findall(r"^\tmeasure\s+" + NAME, text, re.M)}
    return tables, columns, measures


def tmdl_measures(model_dir):
    """{(table, measure): {"expr", "format", "hidden"}} from <model>/definition/tables/*.tmdl, tab-indented as
    Power BI Desktop saves it: a one-line expression, a multi-line one indented three tabs, or a ``` block."""
    out = {}
    for f in sorted(glob.glob(os.path.join(model_dir, "definition", "tables", "*.tmdl"))):
        with open(f, encoding="utf-8-sig") as fh:
            lines = fh.read().splitlines()
        t = next((re.match(r"^table\s+" + NAME, x) for x in lines if x.startswith("table")), None)
        table = unquote(t.group(1)) if t else os.path.splitext(os.path.basename(f))[0]
        i = 0
        while i < len(lines):
            m = MEASURE.match(lines[i])
            i += 1
            if not m:
                continue
            first, expr = m.group(2).strip(), []
            if first.startswith("```"):
                while i < len(lines) and lines[i].strip() != "```":
                    expr.append(lines[i])
                    i += 1
                i += 1
            else:
                expr.append(first)
                while i < len(lines) and lines[i].startswith("\t\t\t"):
                    expr.append(lines[i])
                    i += 1
            fmt, hidden = None, False
            while i < len(lines) and lines[i].startswith("\t\t"):
                line = lines[i]
                i += 1
                if line.startswith("\t\t\t"):
                    continue  # a property's own expression, such as formatStringDefinition
                p = re.match(r"(\w+)\s*(?::\s*(.*)|=\s*(.*))?$", line.strip())
                if not p:
                    continue
                value = (p.group(2) if p.group(2) is not None else p.group(3) or "").strip()
                if p.group(1) == "formatString":
                    fmt = value[1:-1] if len(value) > 1 and value[0] == value[-1] == '"' else value
                elif p.group(1) == "isHidden" and value.lower() in ("", "true"):
                    hidden = True
            out[(table, unquote(m.group(1)))] = {"expr": "\n".join(expr), "format": fmt, "hidden": hidden}
    return out


def pbix_model(pbix):
    """(tables, columns, measures, {measure: DAX}) of the model inside a PBIX, read with PBIXRay."""
    from pbixray import PBIXRay
    m = PBIXRay(pbix)
    try:
        columns = {(r.TableName, r.ColumnName) for r in m.schema.itertuples()}
        dax = {(r.TableName, r.Name): r.Expression for r in m.dax_measures.itertuples()}
        tables = set(m.tables) | {t for t, _ in columns} | {t for t, _ in dax}
    finally:
        if hasattr(m, "close"):
            m.close()
    return tables, columns, set(dax), dax


def check_bindings(report_dir, model):
    if model is None:
        summary.setdefault("bindings", "skipped (no model: give a PBIX with its model, a PBIP, or --model)")
        return
    tables, columns, measures = model
    refs, local = report_refs(report_dir)
    for (kind, table, name), wheres in sorted(refs.items(), key=lambda r: (r[0][0], r[0][1], r[0][2] or "")):
        if table not in tables:
            missing = "table %s" % table
        elif kind == "Column" and (table, name) not in columns:
            missing = "column %s[%s]" % (table, name)
        elif kind == "Measure" and (table, name) not in measures and (table, name) not in local:
            missing = "measure %s[%s]" % (table, name)
        else:
            continue
        add("bindings", "error", wheres[0], "uses %s, which the model does not have%s"
            % (missing, " (and %d more places)" % (len(wheres) - 1) if len(wheres) > 1 else ""))
    summary["bindings"] = "%d fields checked against %d tables, %d columns, %d measures" % (
        len(refs), len(tables), len(columns), len(measures))


# ---------------------------------------------------------------- text fit

def text_width():
    """px(text, face, points): the rendered width at 96 dpi through Windows GDI, or None off Windows."""
    try:
        import ctypes
        from ctypes import wintypes
        gdi32 = ctypes.WinDLL("gdi32")
    except (ImportError, OSError, AttributeError):
        return None
    gdi32.CreateFontW.restype = wintypes.HFONT
    gdi32.CreateFontW.argtypes = [ctypes.c_int] * 5 + [wintypes.DWORD] * 8 + [wintypes.LPCWSTR]
    gdi32.SelectObject.restype = wintypes.HGDIOBJ
    gdi32.SelectObject.argtypes = [wintypes.HDC, wintypes.HGDIOBJ]
    gdi32.CreateCompatibleDC.restype = wintypes.HDC
    gdi32.GetTextExtentPoint32W.argtypes = [wintypes.HDC, wintypes.LPCWSTR, ctypes.c_int, ctypes.POINTER(wintypes.SIZE)]
    gdi32.DeleteObject.argtypes = [wintypes.HGDIOBJ]
    hdc = gdi32.CreateCompatibleDC(None)

    def px(text, face, points):
        font = gdi32.CreateFontW(-round(points * 96 / 72 * 16), 0, 0, 0, 400, 0, 0, 0, 1, 0, 0, 5, 0, face)
        old = gdi32.SelectObject(hdc, font)
        size = wintypes.SIZE()
        gdi32.GetTextExtentPoint32W(hdc, text, len(text), ctypes.byref(size))
        gdi32.SelectObject(hdc, old)
        gdi32.DeleteObject(font)
        return size.cx / 16
    return px


def text_classes(report_dir):
    for f in glob.glob(os.path.join(report_dir, "StaticResources", "SharedResources", "BaseThemes", "*.json")):
        classes = load(f).get("textClasses")
        if classes:
            return classes
    return {}


def font_face(value, default):
    """The first family in a fontFamily literal such as '''Segoe UI'', wf_segoe-ui_normal, ...'."""
    first = (value or "").strip("'").split(",")[0].strip().strip("'")
    return first or default


def title_text(props, resx):
    """The text a title shows: its literal text, or for a title bound to a column of a text table, that column's
    base-language text from --resx. "" when there is no text; None when the text is not known."""
    expr = props.get("text", {}).get("expr")
    if not expr:
        return ""
    if "Literal" in expr:
        return expr["Literal"]["Value"][1:-1].replace("''", "'")
    key = expr.get("Aggregation", {}).get("Expression", {}).get("Column", {}).get("Property")
    return resx.get(key) if key else None


def load_resx(path):
    try:
        return {d.get("name"): (d.findtext("value") or "") for d in ET.parse(path).getroot().findall("data")}
    except ET.ParseError as e:
        fail("--resx %s cannot be read: %s" % (path, e))


def check_text(report_dir, report_pages, resx):
    """Titles and subtitles fit their visual on one line; measure names fit a side legend; a short titled textbox holds
    no paragraph. Base language only: translations usually run longer."""
    px = text_width()
    if px is None:
        summary["text"] = "skipped (measuring text needs Windows)"
        return
    classes = text_classes(report_dir)
    title_face = classes.get("title", {}).get("fontFace", "Segoe UI Semibold")
    title_size = float(classes.get("title", {}).get("fontSize", 12))
    label_face = classes.get("label", {}).get("fontFace", "Segoe UI")
    label_size = float(classes.get("label", {}).get("fontSize", 10))
    n = unknown = 0
    for page, visuals in report_pages:
        for v in visuals:
            if "visual" not in v or v["_abs"][4]:
                continue
            vt = v["visual"].get("visualType")
            vco, o = v["visual"].get("visualContainerObjects", {}), v["visual"].get("objects", {})
            width, height = v["_abs"][2], v["_abs"][3]
            for obj, face, size in (("title", title_face, title_size), ("subTitle", label_face, 10.0)):
                show = literal(vco, obj, "show")
                if show == "false" or (show is None and (obj == "subTitle" or vt in TITLE_OFF_BY_DEFAULT)):
                    continue
                text = title_text((vco.get(obj) or [{}])[0].get("properties", {}), resx)
                if text is None:
                    unknown += 1
                    continue
                if not text:
                    continue
                n += 1
                need = px(text, font_face(literal(vco, obj, "fontFamily"), face), number(literal(vco, obj, "fontSize"), size))
                if need > width - TITLE_MARGIN:
                    add("text", "warning", label(page, v), "%s %r needs %.0f px; the visual leaves %.0f"
                        % (obj, text, need, width - TITLE_MARGIN))
            state = v["visual"].get("query", {}).get("queryState", {})
            side = (literal(o, "legend", "position") or "").strip("'").startswith(("Left", "Right"))
            # The legend lists the measures only when no column feeds it (Series, or a pie's Category).
            by_column = state.get("Series", {}).get("projections") or (
                vt in PIE_CHARTS and state.get("Category", {}).get("projections"))
            if literal(o, "legend", "show") == "true" and side and not by_column:
                room = width * LEGEND_SHARE - LEGEND_MARGIN
                for proj in state.get("Y", {}).get("projections", []):
                    name = proj.get("displayName") or proj.get("field", {}).get("Measure", {}).get("Property")
                    if not name:
                        continue
                    n += 1
                    need = px(name, label_face, label_size)
                    if need > room:
                        add("text", "warning", label(page, v), "legend name %r needs %.0f px; the legend has %.0f"
                            % (name, need, room))
            paragraphs = (o.get("general") or [{}])[0].get("properties", {}).get("paragraphs")
            if vt == "textbox" and paragraphs and height < TEXTBOX_MIN_HEIGHT and literal(vco, "title", "show") == "true":
                add("text", "warning", label(page, v), "a %g px titled textbox has no room for a paragraph and shows a "
                    'scrollbar; empty it ("paragraphs": []) or make it taller' % height)
    summary["text"] = "%d titles, subtitles and legend names measured" % n + (
        "; %d bound titles not measured (--resx gives the text of titles bound to a text table)" % unknown
        if unknown else "")


# ---------------------------------------------------------------- parity

def check_report_parity(pbix, against):
    """Every Report/definition file of the PBIX equals the PBIR folder's file, byte for byte."""
    seen, same = set(), 0
    with zipfile.ZipFile(pbix) as z:
        for n in z.namelist():
            if not n.startswith("Report/definition/") or n.endswith("/"):
                continue
            rel = n[len("Report/"):]
            seen.add(rel)
            path = os.path.join(against, *rel.split("/"))
            if not os.path.isfile(path):
                add("parity", "error", rel, "is in the PBIX but not in %s" % against)
            elif z.read(n) != read_bytes(path):
                add("parity", "error", rel, "differs between the PBIX and the PBIR folder")
            else:
                same += 1
    for d, _, files in os.walk(os.path.join(against, "definition")):
        for f in files:
            rel = os.path.relpath(os.path.join(d, f), against).replace("\\", "/")
            if rel not in seen:
                add("parity", "error", rel, "is in the PBIR folder but not in the PBIX")
    summary["report parity"] = "%d of %d definition files equal" % (same, len(seen))


def check_model_parity(dax, model_dir):
    """Each measure has the same DAX in the PBIX model ({(table, measure): DAX}) and the TMDL, whitespace aside."""
    norm = lambda s: re.sub(r"\s+", " ", s or "").strip()  # noqa: E731
    tmdl = {k: m["expr"] for k, m in tmdl_measures(model_dir).items()}
    for key in sorted(set(dax) | set(tmdl)):
        where = "%s[%s]" % key
        if key not in tmdl:
            add("parity", "error", where, "is in the PBIX model but not in the TMDL")
        elif key not in dax:
            add("parity", "error", where, "is in the TMDL but not in the PBIX model")
        elif norm(dax[key]) != norm(tmdl[key]):
            add("parity", "error", where, "has different DAX in the PBIX and the TMDL")
    summary["model parity"] = "%d PBIX measures, %d TMDL measures" % (len(dax), len(tmdl))


def write_wireframe(report_dir, out):
    """The pbir-utils wireframe (pages, visuals, fields) as one HTML file, for a human look at the layout."""
    try:
        from pbir_utils.report_wireframe_visualizer import get_wireframe_data
        from pbir_utils.template_utils import render_wireframe_html
        with contextlib.redirect_stdout(io.StringIO()):
            html = render_wireframe_html(get_wireframe_data(report_dir, show_hidden=True))
    except Exception as e:  # these two functions are not in pbir-utils' public API
        add("wireframe", "warning", out, "could not render (%s); run: pbir-utils visualize <X.Report>" % e)
        return
    with open(out, "w", encoding="utf-8") as f:
        f.write(html)
    summary["wireframe"] = out


# ---------------------------------------------------------------- output and main

def emit(input_path, summary, findings, as_json, strict=False):
    """Print the result and return the exit code: 1 on an error finding, or on a warning when strict."""
    failing = {"error", "warning"} if strict else {"error"}
    failed = any(f["severity"] in failing for f in findings)
    findings.sort(key=lambda f: (SEVERITIES.index(f["severity"]) if f["severity"] in SEVERITIES else 3,
                                 f["check"], f["where"]))
    if as_json:
        print(json.dumps({"input": input_path, "summary": summary, "findings": findings, "failed": failed}, indent=1))
    else:
        for check, text in summary.items():
            print("%s: %s" % (check, text))
        for f in findings:
            print("%s %s %s: %s" % (f["severity"].upper(), f["check"], f["where"], f["message"]))
        counts = {s: sum(f["severity"] == s for f in findings) for s in SEVERITIES}
        print("errors: %(error)d, warnings: %(warning)d, info: %(info)d" % counts)
    return 1 if failed else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description="Structural tests for a Power BI report saved as PBIR.")
    ap.add_argument("input", help="a *.Report folder, a .pbip project or a .pbix file")
    ap.add_argument("--model", help="the *.SemanticModel TMDL folder to check bindings against")
    ap.add_argument("--against", help="a *.Report folder the PBIX's report must equal")
    ap.add_argument("--model-against", help="a *.SemanticModel TMDL folder the PBIX's measures must equal")
    ap.add_argument("--checks", default=",".join(CHECKS), help="comma-separated subset of %s, or none" % ", ".join(CHECKS))
    ap.add_argument("--rules", help="a project's pbir-utils rule pack, run after the generic rules")
    ap.add_argument("--resx", help="the base-language .resx file holding the text of titles bound to a text table")
    ap.add_argument("--wireframe", help="write the pbir-utils wireframe HTML to this file")
    ap.add_argument("--json", action="store_true", help="print the result as JSON")
    ap.add_argument("--strict", action="store_true", help="fail on warnings too")
    a = ap.parse_args(argv)
    checks = [] if a.checks.strip().lower() == "none" else [c.strip() for c in a.checks.split(",") if c.strip()]
    unknown = [c for c in checks if c not in CHECKS]
    if unknown:
        ap.error("unknown check(s): %s" % ", ".join(unknown))
    for value, option in ((a.rules, "--rules"), (a.resx, "--resx")):
        if value and not os.path.isfile(value):
            ap.error("%s: no such file: %s" % (option, value))
    for value, option in ((a.model, "--model"), (a.against, "--against"), (a.model_against, "--model-against")):
        if value and not os.path.isdir(value):
            ap.error("%s: no such folder: %s" % (option, value))
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    del findings[:]
    summary.clear()
    resx = load_resx(a.resx) if a.resx else {}
    with tempfile.TemporaryDirectory(prefix="pbi-test-") as tmp:
        report_dir, pbix, model_dir = resolve(a.input, tmp)
        if (a.against or a.model_against) and not pbix:
            ap.error("--against and --model-against compare a PBIX; give a .pbix input")
        report_pages = pages(report_dir)  # reads every page and visual first, so a broken file stops the run (exit 2)
        model, dax = None, None
        if "bindings" in checks and (a.model or model_dir):
            model = tmdl_names(a.model or model_dir)
        elif "bindings" in checks and pbix:
            try:
                tables, columns, measures, dax = pbix_model(pbix)
                model = (tables, columns, measures)
            except ImportError:
                add("bindings", "error", "setup", "pbixray is not installed: pip install pbixray")
            except Exception as e:  # a live-connection PBIX has no model to read
                summary["bindings"] = "skipped (PBIXRay could not read a model: %s)" % e
        if "rules" in checks:
            packs = [("generic", GENERIC_RULES)] + ([(os.path.basename(a.rules), a.rules)] if a.rules else [])
            check_rules(report_dir, packs)
        if "geometry" in checks:
            check_geometry(report_pages)
        if "bindings" in checks:
            check_bindings(report_dir, model)
        if "text" in checks:
            check_text(report_dir, report_pages, resx)
        if a.against:
            check_report_parity(pbix, a.against)
        if a.model_against:
            if dax is None:
                try:
                    dax = pbix_model(pbix)[3]
                except ImportError:
                    add("parity", "error", "setup", "pbixray is not installed: pip install pbixray")
                except Exception as e:  # a live-connection PBIX has no model to read
                    add("parity", "error", "setup", "PBIXRay could not read a model: %s" % e)
            if dax is not None:
                check_model_parity(dax, a.model_against)
        if a.wireframe:
            write_wireframe(report_dir, a.wireframe)
    return emit(a.input, summary, findings, a.json, a.strict)


if __name__ == "__main__":
    sys.exit(main())
