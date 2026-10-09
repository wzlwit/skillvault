#!/usr/bin/env python3
"""Test the layout and visuals of a Power BI report: a PBIR folder, a PBIP project or a PBIX file.

Usage:
    python verify_report.py <X.Report | X.pbip | X.pbix> [--model <X.SemanticModel>] [--against <X.Report>]
        [--model-against <X.SemanticModel>] [--checks rules,geometry,bindings|none] [--rules <pbir-rules.yaml>]
        [--wireframe <out.html>] [--json] [--strict]

Checks:
  rules     pbir-utils expression rules, ../rules/pbir-rules.yaml by default: page settings, display units, labels,
            localized titles, alt text.
  geometry  every shown visual lies inside its page; no two shown content visuals overlap. Cards may stack on cards;
            a button over content is a warning. Group offsets are applied, since PBIR stores a grouped visual's
            position relative to its group.
  bindings  every table, column and measure that a visual, page or report filter uses exists in the model: PBIXRay
            reads it from a PBIX; a PBIP or --model gives the TMDL folder.
  parity    --against: the PBIX's Report/definition files equal the PBIR folder byte for byte. --model-against: each
            measure in the PBIX (PBIXRay) has the same DAX as the TMDL, whitespace aside.
--checks picks the first three (default: all). A model-only PBIX carries Desktop's empty placeholder page, so check it
with --checks none --model-against <X.SemanticModel>.
A PBIX is read from a temporary copy; nothing is written next to the input. Exit code 1 on an error, or on a warning
with --strict. Needs pbir-utils (rules, wireframe) and, for a PBIX model, pbixray.
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
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_RULES = os.path.normpath(os.path.join(HERE, "..", "rules", "pbir-rules.yaml"))
CHECKS = ("rules", "geometry", "bindings")
DECORATIVE = {"textbox", "shape", "basicShape", "image"}
BUTTONS = {"actionButton", "pageNavigator", "bookmarkNavigator"}
TOLERANCE = 1.0  # px: touching edges and rounding are not overlaps
NAME = r"('(?:[^']|'')+'|[^\s=']+)"

findings = []
summary = {}


def add(check, severity, where, message):
    findings.append({"check": check, "severity": severity, "where": where, "message": message})


def load(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def read_bytes(path):
    with open(path, "rb") as f:
        return f.read()


def unquote(name):
    return name[1:-1].replace("''", "'") if name.startswith("'") else name


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
    """Copy the PBIR report inside a PBIX (Report/definition/...) to <tmp>/<name>.Report. None for a legacy layout."""
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
        report_dir, legacy = extract_report(p, tmp)
        if report_dir is None:
            raise SystemExit("%s: %s" % (path, "the report is in the legacy Layout format; save it in Power BI Desktop "
                                         "with 'Store PBIX reports using enhanced metadata format (PBIR)' on"
                                         if legacy else "no report found in the PBIX"))
        return report_dir, p, None
    if os.path.isfile(p) and p.lower().endswith(".pbip"):
        rel = next((a["report"]["path"] for a in load(p).get("artifacts", []) if "report" in a), None)
        p = os.path.normpath(os.path.join(os.path.dirname(p), rel)) if rel else os.path.splitext(p)[0] + ".Report"
    if not os.path.isfile(os.path.join(p, "definition", "report.json")):
        raise SystemExit("%s is not a PBIR report folder, PBIP project or PBIX file" % path)
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


# ---------------------------------------------------------------- checks

def check_rules(report_dir, rules_path):
    try:
        import pbir_utils
    except ImportError:
        add("rules", "error", "setup", "pbir-utils is not installed: pip install pbir-utils")
        return
    with contextlib.redirect_stdout(io.StringIO()):
        result = pbir_utils.validate_report(report_dir, source="rules", rules_config=rules_path, strict=False)
    for v in result.violations:
        where = v.get("page_name") or "report"
        if v.get("visual_name"):
            where += " / %s (%s)" % (v["visual_name"], v.get("visual_type", "?"))
        add("rules", v.get("severity", "warning"), where, "%s: %s" % (v.get("rule_id"), v.get("message")))
    summary["rules"] = "%d passed, %d failed" % (result.passed, result.failed)


def check_geometry(report_pages):
    n = 0
    for page, visuals in report_pages:
        width, height = page.get("width", 1280), page.get("height", 720)
        shown = [v for v in visuals if not v["_abs"][4]]
        for v in shown:
            n += 1
            x, y, w, h, _ = v["_abs"]
            if x < -TOLERANCE or y < -TOLERANCE or x + w > width + TOLERANCE or y + h > height + TOLERANCE:
                add("geometry", "error", label(page, v), "lies outside the %d x %d page (x %g, y %g, %g x %g)"
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
        summary["bindings"] = "skipped (no model: give a PBIX with its model, a PBIP, or --model)"
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


def tmdl_measure_dax(model_dir):
    """{(table, measure): DAX} from the TMDL folder: single-line, multi-line (3+ tabs) and ``` blocks."""
    out = {}
    for f in glob.glob(os.path.join(model_dir, "definition", "tables", "*.tmdl")):
        with open(f, encoding="utf-8-sig") as fh:
            lines = fh.read().splitlines()
        t = next((re.match(r"^table\s+" + NAME, x) for x in lines if x.startswith("table")), None)
        table = unquote(t.group(1)) if t else os.path.splitext(os.path.basename(f))[0]
        i = 0
        while i < len(lines):
            m = re.match(r"^\tmeasure\s+" + NAME + r"\s*=\s*(.*)$", lines[i])
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
            out[(table, unquote(m.group(1)))] = "\n".join(expr)
    return out


def check_model_parity(dax, model_dir):
    norm = lambda s: re.sub(r"\s+", " ", s or "").strip()  # noqa: E731
    tmdl = tmdl_measure_dax(model_dir)
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


# ---------------------------------------------------------------- main

def main(argv=None):
    ap = argparse.ArgumentParser(description="Test the layout and visuals of a Power BI report.")
    ap.add_argument("input", help="a *.Report folder, a .pbip project or a .pbix file")
    ap.add_argument("--model", help="the *.SemanticModel TMDL folder to check bindings against")
    ap.add_argument("--against", help="a *.Report folder the PBIX's report must equal")
    ap.add_argument("--model-against", help="a *.SemanticModel TMDL folder the PBIX's measures must equal")
    ap.add_argument("--checks", default=",".join(CHECKS), help="comma-separated subset of %s, or none" % ", ".join(CHECKS))
    ap.add_argument("--rules", default=DEFAULT_RULES, help="pbir-utils rules file (default: the skill's rule pack)")
    ap.add_argument("--wireframe", help="write the pbir-utils wireframe HTML to this file")
    ap.add_argument("--json", action="store_true", help="print the result as JSON")
    ap.add_argument("--strict", action="store_true", help="fail on warnings too")
    a = ap.parse_args(argv)
    checks = [] if a.checks.strip().lower() == "none" else [c.strip() for c in a.checks.split(",") if c.strip()]
    unknown = [c for c in checks if c not in CHECKS]
    if unknown:
        ap.error("unknown check(s): %s" % ", ".join(unknown))
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    del findings[:]
    summary.clear()
    with tempfile.TemporaryDirectory(prefix="pbi-layout-") as tmp:
        report_dir, pbix, model_dir = resolve(a.input, tmp)
        if (a.against or a.model_against) and not pbix:
            ap.error("--against and --model-against compare a PBIX; give a .pbix input")
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
            check_rules(report_dir, a.rules)
        if "geometry" in checks:
            check_geometry(pages(report_dir))
        if "bindings" in checks:
            check_bindings(report_dir, model)
        if a.against:
            check_report_parity(pbix, a.against)
        if a.model_against:
            if dax is None:
                try:
                    dax = pbix_model(pbix)[3]
                except ImportError:
                    add("parity", "error", "setup", "pbixray is not installed: pip install pbixray")
            if dax is not None:
                check_model_parity(dax, a.model_against)
        if a.wireframe:
            write_wireframe(report_dir, a.wireframe)
    failing = {"error", "warning"} if a.strict else {"error"}
    failed = any(f["severity"] in failing for f in findings)
    order = {"error": 0, "warning": 1, "info": 2}
    findings.sort(key=lambda f: (order.get(f["severity"], 3), f["check"], f["where"]))
    if a.json:
        print(json.dumps({"input": a.input, "summary": summary, "findings": findings, "failed": failed}, indent=1))
    else:
        for check, text in summary.items():
            print("%s: %s" % (check, text))
        for f in findings:
            print("%s %s %s: %s" % (f["severity"].upper(), f["check"], f["where"], f["message"]))
        counts = {s: sum(f["severity"] == s for f in findings) for s in ("error", "warning", "info")}
        print("errors: %(error)d, warnings: %(warning)d, info: %(info)d" % counts)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
