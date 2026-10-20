#!/usr/bin/env python3
"""House-style checks for a Power BI report saved in the enhanced report format (PBIR), from a project's style file.

Usage:
    python check_style.py <X.Report | X.pbip | X.pbix> --style <report-style.yaml> [--model <X.SemanticModel>] [--json]

House style is a project's choice, so nothing here is checked by default: the style file (YAML) lists the settings
the team agreed on, and only those are checked. ../examples/report-style.example.yaml shows every setting with
illustrative values, and ../references/rules.md explains them. Checks and the settings that turn them on:
  pages     page.view, page.width, page.height, page.background, page.wallpaper, filtersPane
  units     displayUnits, percentDecimals
  slicers   dateSlicer.mode, dateSlicer.slider, dateSlicer.sameSyncGroup
  titles    titles: bound
  formats   formats             (reads the model's measures)
  blanks    blanks: keep        (reads the model's measures)
  captions  captionSeparator    (reads the model's measures)
The model is --model, or the TMDL folder a PBIP's report binds to by path. Only reads. Output has verify_report.py's
format, and every finding is an error. Exit code 0 with no findings, 1 with findings, 2 when the input or the style
file cannot be used. Needs PyYAML, and verify_report.py from the same folder.
"""
import argparse
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import verify_report as vr  # noqa: E402  (shared readers and output)

VIEWS = ("FitToPage", "FitToWidth", "ActualSize")
PANES = ("collapsed", "expanded", "hidden")
UNITS = {"auto": 0, "none": 1, "thousands": 1e3, "millions": 1e6, "billions": 1e9, "trillions": 1e12}
DATE_MODES = ("Between", "Relative", "Before", "After")
AXIS_CHARTS = {"lineChart", "areaChart", "stackedAreaChart", "clusteredColumnChart", "columnChart",
               "clusteredBarChart", "barChart", "lineStackedColumnComboChart", "lineClusteredColumnComboChart"}
COMBO_CHARTS = {"lineStackedColumnComboChart", "lineClusteredColumnComboChart"}
# Every setting a style file may hold; nested ones list their keys.
SETTINGS = {"page": ("view", "width", "height", "background", "wallpaper"), "filtersPane": None, "displayUnits": None,
            "percentDecimals": None, "dateSlicer": ("mode", "slider", "sameSyncGroup"), "titles": None,
            "formats": None, "blanks": None, "captionSeparator": None}
MODEL_CHECKS = (("formats", "formats"), ("blanks", "blanks"), ("captionSeparator", "captions"))

STRING = re.compile(r'"(?:[^"]|"")*"')
CONSTANT = re.compile(r'(?:""|-?\d+(?:\.\d+)?)')
FORMAT_CALL = re.compile(r"\bFORMAT\s*\(", re.I)

findings = []
summary = {}


def add(check, where, message):
    findings.append({"check": check, "severity": "error", "where": where, "message": message})


def shown(value):
    return "%g" % value if isinstance(value, (int, float)) and not isinstance(value, bool) else str(value)


# ---------------------------------------------------------------- the style file

def load_style(path):
    """The style file's settings, after checking every name and value; exits with code 2 on a problem."""
    try:
        import yaml
    except ImportError:
        vr.fail("PyYAML is not installed: pip install pyyaml")
    try:
        with open(path, encoding="utf-8-sig") as f:
            style = yaml.safe_load(f)
    except yaml.YAMLError as e:
        vr.fail("%s is not valid YAML: %s" % (path, e))
    style = {} if style is None else style
    if not isinstance(style, dict):
        vr.fail("%s: expected settings such as 'page:' or 'displayUnits:'" % path)
    problems = []

    def need(ok, message):
        if not ok:
            problems.append(message)
    for key, value in style.items():
        if key not in SETTINGS:
            problems.append("unknown setting %r" % key)
        elif SETTINGS[key] is not None:
            if isinstance(value, dict):
                problems += ["unknown setting %s.%s" % (key, k) for k in value if k not in SETTINGS[key]]
            else:
                problems.append("%s needs nested settings (%s)" % (key, ", ".join(SETTINGS[key])))
    page = style.get("page") if isinstance(style.get("page"), dict) else {}
    slicer = style.get("dateSlicer") if isinstance(style.get("dateSlicer"), dict) else {}
    number = lambda x: isinstance(x, (int, float)) and not isinstance(x, bool)  # noqa: E731
    if "view" in page:
        need(page["view"] in VIEWS, "page.view must be one of %s" % ", ".join(VIEWS))
    for k in ("width", "height"):
        if k in page:
            need(number(page[k]) and page[k] > 0, "page.%s must be a number of pixels" % k)
    for k in ("background", "wallpaper"):
        if k in page:
            need(isinstance(page[k], str) and re.fullmatch(r"#[0-9A-Fa-f]{6}", page[k]),
                 'page.%s must be a quoted color such as "#FFFFFF"' % k)
    if "filtersPane" in style:
        need(style["filtersPane"] in PANES, "filtersPane must be one of %s" % ", ".join(PANES))
    if "displayUnits" in style:
        need(str(style["displayUnits"]).lower() in UNITS, "displayUnits must be one of %s" % ", ".join(UNITS))
    if "percentDecimals" in style:
        need(number(style["percentDecimals"]) and style["percentDecimals"] == int(style["percentDecimals"]) >= 0,
             "percentDecimals must be a whole number")
    if "mode" in slicer:
        need(slicer["mode"] in DATE_MODES, "dateSlicer.mode must be one of %s" % ", ".join(DATE_MODES))
    for k in ("slider", "sameSyncGroup"):
        if k in slicer:
            need(isinstance(slicer[k], bool), "dateSlicer.%s must be true or false" % k)
    if "titles" in style:
        need(style["titles"] == "bound", "titles must be bound")
    if "formats" in style:
        need(isinstance(style["formats"], list) and style["formats"]
             and all(isinstance(f, str) and f for f in style["formats"]), "formats must be a list of format strings")
    if "blanks" in style:
        need(style["blanks"] == "keep", "blanks must be keep")
    if "captionSeparator" in style:
        need(isinstance(style["captionSeparator"], str) and style["captionSeparator"],
             "captionSeparator must be a quoted string")
    if problems:
        vr.fail("%s: %s" % (path, "; ".join(problems)))
    return style


# ---------------------------------------------------------------- report checks

def check_pages(report_dir, report_pages, style):
    """Each page's view, size, canvas color and wallpaper; the Filters pane in the style's state, set once in
    report.json."""
    want, pane = style.get("page") or {}, style.get("filtersPane")
    if pane:
        o = vr.load(os.path.join(report_dir, "definition", "report.json")).get("objects", {})
        visible, expanded = vr.literal(o, "outspacePane", "visible"), vr.literal(o, "outspacePane", "expanded")
        state = "hidden" if visible == "false" else "collapsed" if expanded == "false" else "expanded"
        if state != pane:
            add("pages", "report.json", "the Filters pane is %s; the style wants it %s" % (state, pane))
    for page, _ in report_pages:
        where, o = vr.label(page), page.get("objects", {})
        if "view" in want and page.get("displayOption") != want["view"]:
            add("pages", where, "the page view is %s; the style wants %s" % (page.get("displayOption"), want["view"]))
        for k, word in (("width", "wide"), ("height", "tall")):
            if k in want and page.get(k) != want[k]:
                add("pages", where, "the page is %s px %s; the style wants %s" % (shown(page.get(k)), word, shown(want[k])))
        if "background" in want:
            try:
                color = o["background"][0]["properties"]["color"]["solid"]["color"]["expr"]["Literal"]["Value"]
            except (KeyError, IndexError, TypeError):
                color = None
            transparency = vr.literal(o, "background", "transparency")
            zero = transparency is not None and re.fullmatch(r"0(?:\.0+)?[DL]?", transparency)
            if (color or "").upper() != "'%s'" % want["background"].upper() or not zero:
                add("pages", where, "the canvas is %s at transparency %s; the style wants %s at 0"
                    % ((color or "unset").strip("'"), transparency or "unset", want["background"]))
        if "wallpaper" in want:
            # The wallpaper (objects.outspace) colors the area outside the page; it is not the Filters pane
            # (outspacePane). Unlike the canvas, its color shows without an explicit transparency (observed).
            try:
                color = o["outspace"][0]["properties"]["color"]["solid"]["color"]["expr"]["Literal"]["Value"]
            except (KeyError, IndexError, TypeError):
                color = None
            transparency = vr.literal(o, "outspace", "transparency")
            clear = transparency is None or re.fullmatch(r"0(?:\.0+)?[DL]?", transparency)
            if (color or "").upper() != "'%s'" % want["wallpaper"].upper() or not clear:
                add("pages", where, "the wallpaper is %s%s; the style wants %s"
                    % ((color or "unset").strip("'"), "" if transparency is None else " at transparency " + transparency,
                       want["wallpaper"]))
        if pane and (vr.literal(o, "outspacePane", "expanded") is not None
                     or vr.literal(o, "outspacePane", "visible") is not None):
            add("pages", where, "sets the Filters pane for this page; set it once in report.json")
    summary["pages"] = "%d pages checked%s" % (len(report_pages), " and the Filters pane" if pane else "")


def check_units(report_pages, style):
    """Display units wherever a number shows (card values, value axes, shown data labels), and the decimals of pie and
    donut percent labels."""
    units = UNITS[str(style["displayUnits"]).lower()] if "displayUnits" in style else None
    decimals = style.get("percentDecimals")
    n = 0
    for page, visuals in report_pages:
        for v in visuals:
            if "visual" not in v:
                continue
            vt, o = v["visual"].get("visualType"), v["visual"].get("objects", {})
            pie_labels = vt in vr.PIE_CHARTS and vr.literal(o, "labels", "show") != "false"
            props = []
            if vt == "card" or pie_labels:
                props.append(("labels", "labelDisplayUnits"))
            elif vt in AXIS_CHARTS:
                if vr.literal(o, "valueAxis", "show") != "false":
                    props.append(("valueAxis", "labelDisplayUnits"))
                    y2 = v["visual"].get("query", {}).get("queryState", {}).get("Y2")
                    if vt in COMBO_CHARTS and y2 and vr.literal(o, "valueAxis", "secShow") != "false":
                        props.append(("valueAxis", "secLabelDisplayUnits"))
                if vr.literal(o, "labels", "show") == "true":
                    props.append(("labels", "labelDisplayUnits"))
            for obj, prop in props if units is not None else []:
                n += 1
                got = vr.literal(o, obj, prop)
                if vr.number(got, 0) != units:
                    add("units", vr.label(page, v), "%s.%s is %s; the style wants display units %s (%gD)"
                        % (obj, prop, got or "unset (Auto)", style["displayUnits"], units))
            if decimals is not None and pie_labels:
                n += 1
                got = vr.literal(o, "labels", "percentageLabelPrecision")
                if got is None or vr.number(got, -1) != decimals:
                    add("units", vr.label(page, v), "labels.percentageLabelPrecision is %s; the style wants %d (%dD)"
                        % (got or "unset", decimals, decimals))
    summary["units"] = "%d settings checked" % n


def check_slicers(report_pages, want):
    """Date slicers (slicers in a date mode) use the style's mode, show or hide their slider as it says, and share one
    sync group, so a range follows the user from page to page."""
    n, groups = 0, set()
    for page, visuals in report_pages:
        for v in visuals:
            if "visual" not in v or v["visual"].get("visualType") != "slicer":
                continue
            o = v["visual"].get("objects", {})
            mode = (vr.literal(o, "data", "mode") or "").strip("'")
            if mode not in DATE_MODES:
                continue
            n += 1
            where = vr.label(page, v)
            if "mode" in want and mode != want["mode"]:
                add("slicers", where, "the mode is %s; the style wants %s" % (mode, want["mode"]))
            if "slider" in want and mode == "Between":
                hidden = vr.literal(o, "slider", "show") == "false"
                if hidden == want["slider"]:
                    add("slicers", where, "the slider is %s; the style wants it %s"
                        % ("hidden" if hidden else "shown", "shown" if want["slider"] else "hidden"))
            groups.add((v["visual"].get("syncGroup") or {}).get("groupName"))
    if want.get("sameSyncGroup") and n > 1 and (len(groups) > 1 or None in groups):
        add("slicers", "report", "date slicers are in sync groups %s; the style wants one group"
            % ", ".join(sorted(str(g) for g in groups)))
    summary["slicers"] = "%d date slicers checked" % n


def check_titles(report_pages):
    """Shown titles and subtitles take their text from a field, such as a translation table, not literal text."""
    n = 0
    for page, visuals in report_pages:
        for v in visuals:
            if "visual" not in v:
                continue
            vt, vco = v["visual"].get("visualType"), v["visual"].get("visualContainerObjects", {})
            for obj in ("title", "subTitle"):
                show = vr.literal(vco, obj, "show")
                if show == "false" or (show is None and (obj == "subTitle" or vt in vr.TITLE_OFF_BY_DEFAULT)):
                    continue
                expr = (vco.get(obj) or [{}])[0].get("properties", {}).get("text", {}).get("expr")
                if not expr:
                    continue
                n += 1
                if "Literal" in expr:
                    add("titles", vr.label(page, v), "the %s %s is literal text; the style wants it bound to a field"
                        % (obj, expr["Literal"]["Value"]))
    summary["titles"] = "%d shown titles and subtitles checked" % n


# ---------------------------------------------------------------- measure checks

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
    """How a measure turns a blank into a value, if it does: COALESCE, an IF on ISBLANK or ISEMPTY with a constant
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
    for key, m in sorted(ms.items()):
        found = blank_fills(m["expr"])
        if found:
            bad += 1
            add("blanks", "%s[%s]" % key, "replaces a blank (%s)" % ", ".join(found))
    summary["blanks"] = "%d of %d measures keep a blank" % (len(ms) - bad, len(ms))


def format_allowed(fmt, allowed):
    """True when fmt equals an allowed format string, or an allowed regular expression matches all of it."""
    for a in allowed:
        if fmt == a:
            return True
        try:
            if re.fullmatch(a, fmt):
                return True
        except re.error:
            pass
    return False


def check_formats(ms, allowed):
    """Every visible measure with a format string uses one of the style's formats."""
    n = 0
    for key, m in sorted(ms.items()):
        if m["hidden"] or m["format"] is None:
            continue
        n += 1
        if not format_allowed(m["format"], allowed):
            add("formats", "%s[%s]" % key, "formatString %r is not one of the style's formats" % m["format"])
    summary["formats"] = "%d visible measures checked" % n


def check_captions(ms, separator):
    """A caption that joins a number and a name with the separator puts the number first, so a narrow card cuts the
    name, not the number."""
    sep, n = '"%s"' % separator, 0
    for key, m in sorted(ms.items()):
        text = re.sub(r"\s+", " ", m["expr"])
        if sep not in text or not FORMAT_CALL.search(text):
            continue
        n += 1
        if FORMAT_CALL.search(text.split(sep, 1)[1]):
            add("captions", "%s[%s]" % key, "puts its number after the name; a narrow card cuts the number")
    summary["captions"] = "%d number-and-name captions checked" % n


# ---------------------------------------------------------------- main

def main(argv=None):
    ap = argparse.ArgumentParser(description="House-style checks for a Power BI report saved as PBIR.")
    ap.add_argument("input", help="a *.Report folder, a .pbip project or a .pbix file")
    ap.add_argument("--style", required=True, help="the project's style file (YAML)")
    ap.add_argument("--model", help="the *.SemanticModel TMDL folder for the formats, blanks and captionSeparator settings")
    ap.add_argument("--json", action="store_true", help="print the result as JSON")
    a = ap.parse_args(argv)
    if not os.path.isfile(a.style):
        ap.error("--style: no such file: %s" % a.style)
    if a.model and not os.path.isdir(a.model):
        ap.error("--model: no such folder: %s" % a.model)
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(errors="backslashreplace")
    del findings[:]
    summary.clear()
    style = load_style(a.style)
    summary["style"] = "%s, %d settings" % (os.path.basename(a.style), len(style))
    with tempfile.TemporaryDirectory(prefix="pbi-style-") as tmp:
        report_dir, _, model_dir = vr.resolve(a.input, tmp)
        model_dir = a.model or model_dir
        report_pages = vr.pages(report_dir)
        if "page" in style or "filtersPane" in style:
            check_pages(report_dir, report_pages, style)
        if "displayUnits" in style or "percentDecimals" in style:
            check_units(report_pages, style)
        if "dateSlicer" in style:
            check_slicers(report_pages, style["dateSlicer"])
        if "titles" in style:
            check_titles(report_pages)
        wanted = [(key, check) for key, check in MODEL_CHECKS if key in style]
        ms = vr.tmdl_measures(model_dir) if wanted and model_dir else None
        for key, check in wanted:
            if ms is None:
                summary[check] = "skipped (no model: give --model, or a PBIP whose report binds to its model by path)"
            elif key == "formats":
                check_formats(ms, style["formats"])
            elif key == "blanks":
                check_blanks(ms)
            else:
                check_captions(ms, style["captionSeparator"])
    return vr.emit(a.input, summary, findings, a.json)


if __name__ == "__main__":
    sys.exit(main())
