#!/usr/bin/env python3
"""Static checks for the Power BI report visual conventions in SKILL.md.

Usage:
    python check_visual_conventions.py <Report folder> [--model <SemanticModel folder>] [--resx <en-US .resx>]
        [--checks pages,units,blanks,formats,captions,text] [--format <regex>]... [--separator " · "]

<Report folder> is the "*.Report" folder of a PBIR project. --model is the "*.SemanticModel" folder whose
definition/tables/*.tmdl hold the measures; the blanks, formats and captions checks need it. --resx is the en-US RESX
that localized titles bind to; the text check reads bound titles from it. Exit code 1 when a check finds a problem.
The text check measures with Windows GDI and is skipped elsewhere. Standard library only.
"""
import argparse
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

CHECKS = ("pages", "units", "blanks", "formats", "captions", "text")
CANVAS = "'#FAF9F8'"
# Counts, rates, every other number with one decimal and a thousands separator, durations with a literal unit.
FORMATS = [r"#,##0", r"0\.0%;-0\.0%;0\.0%", r"#,##0\.0", r"#,##0\.0 \\[A-Za-z]+", r"Short Date", r"Long Date"]
AXIS_CHARTS = {"lineChart", "areaChart", "stackedAreaChart", "clusteredColumnChart", "columnChart",
               "clusteredBarChart", "barChart", "lineStackedColumnComboChart", "lineClusteredColumnComboChart"}
COMBO_CHARTS = {"lineStackedColumnComboChart", "lineClusteredColumnComboChart"}
PIE_CHARTS = {"donutChart", "pieChart"}
# Visual types whose title is off unless the visual turns it on (a button's title often holds an internal name).
TITLE_OFF_BY_DEFAULT = {"actionButton", "shape", "basicShape", "image", "textbox", "slicer", "advancedSlicerVisual",
                        "pageNavigator", "bookmarkNavigator"}
# Calibrated on a 1280 x 720 report in Segoe UI: a title needs its text width plus 24 px; a legend on the left or right
# gets 30% of the visual's width, minus about 30 px for the marker and padding; a titled textbox under 48 px has no room
# for a paragraph under the title.
TITLE_MARGIN, LEGEND_SHARE, LEGEND_MARGIN, TEXTBOX_MIN_HEIGHT = 24, 0.3, 30, 48

STRING = re.compile(r'"(?:[^"]|"")*"')
CONSTANT = re.compile(r'(?:""|-?\d+(?:\.\d+)?)')
MEASURE = re.compile(r"^\tmeasure\s+('(?:[^']|'')+'|[^\s=']+)\s*=\s*(.*)$")
FORMAT_CALL = re.compile(r"\bFORMAT\s*\(", re.I)

findings = []


def problem(check, where, message):
    findings.append("%s %s: %s" % (check.upper(), where, message))


def load(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def literal(objects, name, prop):
    try:
        return objects[name][0]["properties"][prop]["expr"]["Literal"]["Value"]
    except (KeyError, IndexError, TypeError):
        return None


def color(objects, name, prop):
    try:
        return objects[name][0]["properties"][prop]["solid"]["color"]["expr"]["Literal"]["Value"]
    except (KeyError, IndexError, TypeError):
        return None


def is_zero(value):
    return value is not None and re.fullmatch(r"0(?:\.0+)?[DL]?", value) is not None


def number(value, default):
    """The number in a literal such as 11D, 11L or '11' (Desktop writes all three for font sizes)."""
    m = re.search(r"\d+(?:\.\d+)?", value or "")
    return float(m.group()) if m else default


def visuals(report):
    for f in sorted(glob.glob(os.path.join(report, "definition", "pages", "*", "visuals", "*", "visual.json"))):
        v = load(f)
        if "visual" in v:
            yield os.path.relpath(f, report), v


# ---------------------------------------------------------------- pages and units

def check_pages(report):
    """Every page Fit to width on the #FAF9F8 canvas at 0% transparency; the Filters pane collapsed in report.json,
    still visible, and never set per page."""
    d = os.path.join(report, "definition")
    rep = load(os.path.join(d, "report.json")).get("objects", {})
    if literal(rep, "outspacePane", "expanded") != "false" or literal(rep, "outspacePane", "visible") == "false":
        problem("pages", "report.json", "the Filters pane must be collapsed (outspacePane expanded false) and visible")
    pages = sorted(glob.glob(os.path.join(d, "pages", "*", "page.json")))
    for f in pages:
        page, where = load(f), os.path.relpath(f, report)
        o = page.get("objects", {})
        if page.get("displayOption") != "FitToWidth":
            problem("pages", where, "displayOption is %s, not FitToWidth" % page.get("displayOption"))
        if (color(o, "background", "color") or "").upper() != CANVAS or not is_zero(literal(o, "background", "transparency")):
            problem("pages", where, "the canvas background must be #FAF9F8 at transparency 0")
        if literal(o, "outspacePane", "expanded") is not None or literal(o, "outspacePane", "visible") is not None:
            problem("pages", where, "sets the Filters pane per page; set it once in report.json")
    print("pages: report.json and %d pages checked" % len(pages))


def check_units(report):
    """Display units None (1D) wherever a number shows: card values, value axes, shown data labels. Pie and donut
    percent labels have one decimal."""
    n = 0
    for where, v in visuals(report):
        vt, o = v["visual"].get("visualType"), v["visual"].get("objects", {})
        need = []
        if vt == "card":
            need.append(("labels", "labelDisplayUnits"))
        elif vt in PIE_CHARTS and literal(o, "labels", "show") != "false":
            need += [("labels", "labelDisplayUnits"), ("labels", "percentageLabelPrecision")]
        elif vt in AXIS_CHARTS:
            if literal(o, "valueAxis", "show") != "false":
                need.append(("valueAxis", "labelDisplayUnits"))
                y2 = v["visual"].get("query", {}).get("queryState", {}).get("Y2")
                if vt in COMBO_CHARTS and y2 and literal(o, "valueAxis", "secShow") != "false":
                    need.append(("valueAxis", "secLabelDisplayUnits"))
            if literal(o, "labels", "show") == "true":
                need.append(("labels", "labelDisplayUnits"))
        for obj, prop in need:
            n += 1
            got = literal(o, obj, prop)
            if got != "1D":
                want = "one decimal" if prop == "percentageLabelPrecision" else "display units None"
                problem("units", where, "%s.%s is %s, not 1D (%s)" % (obj, prop, got, want))
    print("units: %d settings checked" % n)


# ---------------------------------------------------------------- measures

def unquote(name):
    return name[1:-1].replace("''", "'") if name.startswith("'") else name


def measures(model):
    """{name: {table, expr, format, hidden}} from <model>/definition/tables/*.tmdl, tab-indented as Desktop saves it."""
    out = {}
    for f in sorted(glob.glob(os.path.join(model, "definition", "tables", "*.tmdl"))):
        with open(f, encoding="utf-8-sig") as fh:
            lines = fh.read().splitlines()
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
            out[unquote(m.group(1))] = {"table": os.path.splitext(os.path.basename(f))[0],
                                        "expr": "\n".join(expr), "format": fmt, "hidden": hidden}
    return out


def code_of(expr):
    """The DAX with string literals emptied ("") and comments removed, so text inside strings cannot match."""
    code = STRING.sub('""', expr)
    code = re.sub(r"/\*.*?\*/", " ", code, flags=re.S)
    return re.sub(r"(//|--)[^\n]*", " ", code)


def call_args(code, fn):
    """The top-level arguments of every call of `fn` in `code`; [names] and 'tables' are skipped whole."""
    for m in re.finditer(r"\b%s\s*\(" % fn, code, re.I):
        depth, i, start, args = 1, m.end(), m.end(), []
        while i < len(code):
            c = code[i]
            if c in "['":
                j = code.find("]" if c == "[" else "'", i + 1)
                i = len(code) if j < 0 else j + 1
                continue
            if c in "({":
                depth += 1
            elif c in ")}":
                depth -= 1
                if depth == 0:
                    break
            elif c == "," and depth == 1:
                args.append(code[start:i].strip())
                start = i + 1
            i += 1
        args.append(code[start:i].strip())
        yield args


def blank_fills(expr):
    """How a measure turns a blank into a value, if it does: COALESCE, an IF on ISBLANK/ISEMPTY with a constant
    branch, + 0, a DIVIDE alternate result other than BLANK(), or a dash or N/A text."""
    code, found = code_of(expr), []
    if re.search(r"\bCOALESCE\s*\(", code, re.I):
        found.append("COALESCE")
    for args in call_args(code, "IF"):
        if re.match(r"(?:NOT\s*\(?\s*)?IS(?:BLANK|EMPTY)\s*\(", args[0], re.I) and \
                any(CONSTANT.fullmatch(a) for a in args[1:]):
            found.append("IF on ISBLANK/ISEMPTY with a constant branch")
            break
    if re.search(r"\+\s*0(?![\w.])|(?<![\w.\]])0\s*\+", code):
        found.append("+ 0")
    for args in call_args(code, "DIVIDE"):
        if len(args) > 2 and not re.fullmatch(r"BLANK\s*\(\s*\)", args[2], re.I):
            found.append("DIVIDE alternate result %s" % args[2])
            break
    for s in STRING.findall(expr):
        if re.fullmatch('"(?:[-\u2013\u2014]+|[Nn]/[Aa])"', s):
            found.append("text %s" % s)
            break
    return found


def check_blanks(ms):
    """A blank stays blank: no measure replaces it, so a card shows "(Blank)" and a table cell stays empty."""
    bad = 0
    for name, m in sorted(ms.items()):
        found = blank_fills(m["expr"])
        if found:
            bad += 1
            problem("blanks", "%s[%s]" % (m["table"], name), "replaces a blank (%s)" % ", ".join(found))
    print("blanks: %d of %d measures keep a blank" % (len(ms) - bad, len(ms)))


def check_formats(ms, allowed):
    """Every visible measure with a format string uses one of the report formats."""
    n = 0
    for name, m in sorted(ms.items()):
        if m["hidden"] or m["format"] is None:
            continue
        n += 1
        if not any(re.fullmatch(p, m["format"]) for p in allowed):
            problem("formats", "%s[%s]" % (m["table"], name), "formatString %r is not a report format" % m["format"])
    print("formats: %d visible measures checked" % n)


def check_captions(ms, separator):
    """A caption that joins a number and a name with the separator puts the number first, so a narrow card cuts the
    name, not the number."""
    sep, n = '"%s"' % separator, 0
    for name, m in sorted(ms.items()):
        text = re.sub(r"\s+", " ", m["expr"])
        if sep not in text or not FORMAT_CALL.search(text):
            continue
        n += 1
        if FORMAT_CALL.search(text.split(sep, 1)[1]):
            problem("captions", "%s[%s]" % (m["table"], name), "puts its number after the name; a narrow card cuts it")
    print("captions: %d number-and-name captions checked" % n)


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


def text_classes(report):
    for f in glob.glob(os.path.join(report, "StaticResources", "SharedResources", "BaseThemes", "*.json")):
        classes = load(f).get("textClasses")
        if classes:
            return classes
    return {}


def font_face(value, default):
    """The first family in a fontFamily literal such as '''Segoe UI'', wf_segoe-ui_normal, ...'."""
    first = (value or "").strip("'").split(",")[0].strip().strip("'")
    return first or default


def bound_text(props, resx):
    expr = props.get("text", {}).get("expr", {})
    if "Literal" in expr:
        return expr["Literal"]["Value"][1:-1].replace("''", "'")
    key = expr.get("Aggregation", {}).get("Expression", {}).get("Column", {}).get("Property")
    return resx.get(key) if key else None


def culture_captions(model):
    """Measure and column captions from <model>/definition/cultures/en-US.tmdl."""
    out, current = {}, None
    path = os.path.join(model, "definition", "cultures", "en-US.tmdl") if model else ""
    if not os.path.exists(path):
        return out
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh.read().splitlines():
            m = re.match(r"^\t+(?:measure|column)\s+('(?:[^']|'')+'|\S+)\s*$", line)
            if m:
                current = unquote(m.group(1))
                continue
            c = re.match(r"^\t+caption:\s*(.*)$", line)
            if c and current:
                out[current] = c.group(1).strip()
                current = None
    return out


def check_text(report, resx, captions):
    """Titles and subtitles fit their visual on one line; legend names fit a side legend; a short titled textbox holds
    no paragraph, which would overflow and show a scrollbar. English only: other languages run longer."""
    px = text_width()
    if px is None:
        print("text: skipped (needs Windows GDI)")
        return
    classes = text_classes(report)
    title_face = classes.get("title", {}).get("fontFace", "Segoe UI Semibold")
    title_size = float(classes.get("title", {}).get("fontSize", 12))
    label_face = classes.get("label", {}).get("fontFace", "Segoe UI")
    label_size = float(classes.get("label", {}).get("fontSize", 10))
    n = 0
    for where, v in visuals(report):
        vt = v["visual"].get("visualType")
        vco, o = v["visual"].get("visualContainerObjects", {}), v["visual"].get("objects", {})
        width, height = v.get("position", {}).get("width", 0), v.get("position", {}).get("height", 0)
        for obj, face, size in (("title", title_face, title_size), ("subTitle", label_face, 10.0)):
            props = (vco.get(obj) or [{}])[0].get("properties", {})
            show = literal(vco, obj, "show")
            hidden = show == "false" or (show is None and (obj == "subTitle" or vt in TITLE_OFF_BY_DEFAULT))
            text = bound_text(props, resx) if props and not hidden else None
            if not text:
                continue
            n += 1
            need = px(text, font_face(literal(vco, obj, "fontFamily"), face), number(literal(vco, obj, "fontSize"), size))
            if need > width - TITLE_MARGIN:
                problem("text", where, "%s %r needs %.0f px; the visual leaves %.0f" % (obj, text, need, width - TITLE_MARGIN))
        side = (literal(o, "legend", "position") or "").strip("'").startswith(("Left", "Right"))
        if literal(o, "legend", "show") == "true" and side:
            room = width * LEGEND_SHARE - LEGEND_MARGIN
            for proj in v["visual"].get("query", {}).get("queryState", {}).get("Y", {}).get("projections", []):
                measure = proj.get("field", {}).get("Measure", {}).get("Property")
                if not measure:
                    continue
                n += 1
                name = captions.get(measure, measure)
                need = px(name, label_face, label_size)
                if need > room:
                    problem("text", where, "legend name %r needs %.0f px; the legend has %.0f" % (name, need, room))
        paragraphs = (o.get("general") or [{}])[0].get("properties", {}).get("paragraphs")
        if vt == "textbox" and paragraphs and height < TEXTBOX_MIN_HEIGHT \
                and literal(vco, "title", "show") == "true":
            problem("text", where, 'a %d px titled textbox has no room for a paragraph and shows a scrollbar; '
                    'use "paragraphs": []' % height)
    print("text: %d titles, subtitles and legend names checked" % n)


# ---------------------------------------------------------------- main

def load_resx(path):
    return {d.get("name"): (d.findtext("value") or "") for d in ET.parse(path).getroot().findall("data")}


def main(argv=None):
    ap = argparse.ArgumentParser(description="Check a PBIR report against the Power BI report visual conventions.")
    ap.add_argument("report", help="the *.Report folder")
    ap.add_argument("--model", help="the *.SemanticModel folder with definition/tables/*.tmdl")
    ap.add_argument("--resx", help="the en-US RESX that localized titles bind to")
    ap.add_argument("--checks", default=",".join(CHECKS), help="comma-separated subset of " + ", ".join(CHECKS))
    ap.add_argument("--format", action="append", default=[], help="another allowed formatString (regex)")
    ap.add_argument("--separator", default=" \u00b7 ", help='caption separator (default " \u00b7 ")')
    a = ap.parse_args(argv)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    checks = [c.strip() for c in a.checks.split(",") if c.strip()]
    unknown = [c for c in checks if c not in CHECKS]
    if unknown:
        ap.error("unknown check(s): %s" % ", ".join(unknown))
    if not os.path.isfile(os.path.join(a.report, "definition", "report.json")):
        ap.error("%s is not a PBIR report folder (no definition/report.json)" % a.report)
    del findings[:]
    ms = measures(a.model) if a.model else {}
    resx = load_resx(a.resx) if a.resx else {}
    if "pages" in checks:
        check_pages(a.report)
    if "units" in checks:
        check_units(a.report)
    for name, run in (("blanks", lambda: check_blanks(ms)), ("formats", lambda: check_formats(ms, FORMATS + a.format)),
                      ("captions", lambda: check_captions(ms, a.separator))):
        if name in checks:
            run() if a.model else print("%s: skipped (no --model)" % name)
    if "text" in checks:
        captions = dict(resx)
        captions.update(culture_captions(a.model))
        check_text(a.report, resx, captions)
    for f in findings:
        print(f)
    print("findings: %d" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
