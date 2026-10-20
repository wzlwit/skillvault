"""Tests for scripts/check_style.py on a small synthetic PBIR report, its TMDL model and the shipped example style file.

Run from the skill folder: python -m unittest discover -s tests   (needs PyYAML)
"""
import contextlib
import copy
import io
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import check_style as cs  # noqa: E402

try:
    import yaml  # noqa: F401
    HAVE_YAML = True
except ImportError:
    HAVE_YAML = False
EXAMPLE = os.path.join(HERE, "..", "examples", "report-style.example.yaml")


def lit(value):
    return {"expr": {"Literal": {"Value": value}}}


def props(**kw):
    return [{"properties": {k: lit(v) for k, v in kw.items()}}]


def bound_title(key):
    return [{"properties": {"show": lit("true"), "text": {"expr": {"Aggregation": {"Expression": {"Column": {
        "Expression": {"SourceRef": {"Entity": "Texts"}}, "Property": key}}, "Function": 3}}}}}]


TOTAL = {"field": {"Measure": {"Expression": {"SourceRef": {"Entity": "Sales"}}, "Property": "Total Sales"}}}
MARGIN = {"field": {"Measure": {"Expression": {"SourceRef": {"Entity": "Sales"}}, "Property": "Margin %"}}}
REPORT = {"objects": {"outspacePane": props(expanded="false", visible="true")}}
PAGE = {"name": "p1", "displayName": "Summary", "displayOption": "FitToPage", "width": 1280, "height": 720,
        "objects": {"background": [{"properties": {"color": {"solid": {"color": lit("'#FFFFFF'")}},
                                                   "transparency": lit("0D")}}],
                    "outspace": [{"properties": {"color": {"solid": {"color": lit("'#FFFFFF'")}}}}]}}
SLICER = {"name": "dates", "position": {"x": 900, "y": 380, "width": 300, "height": 100},
          "visual": {"visualType": "slicer",
                     "objects": {"data": props(mode="'Between'"), "slider": props(show="true")},
                     "syncGroup": {"groupName": "Dates", "fieldChanges": True, "filterChanges": True}}}
VISUALS = {
    "kpi": {"name": "kpi", "position": {"x": 0, "y": 0, "width": 200, "height": 60},
            "visual": {"visualType": "card", "objects": {"labels": props(labelDisplayUnits="1D")},
                       "visualContainerObjects": {"title": bound_title("SalesTitle")}}},
    "share": {"name": "share", "position": {"x": 0, "y": 80, "width": 400, "height": 260},
              "visual": {"visualType": "donutChart", "query": {"queryState": {"Y": {"projections": [TOTAL]}}},
                         "objects": {"labels": props(show="true", labelDisplayUnits="1D", percentageLabelPrecision="1D")},
                         "visualContainerObjects": {"title": bound_title("ShareTitle")}}},
    "trend": {"name": "trend", "position": {"x": 420, "y": 80, "width": 400, "height": 260},
              "visual": {"visualType": "lineChart", "query": {"queryState": {"Y": {"projections": [TOTAL]}}},
                         "objects": {"valueAxis": props(show="true", labelDisplayUnits="1D")},
                         "visualContainerObjects": {"title": bound_title("TrendTitle")}}},
    "combo": {"name": "combo", "position": {"x": 840, "y": 80, "width": 400, "height": 260},
              "visual": {"visualType": "lineClusteredColumnComboChart",
                         "query": {"queryState": {"Y": {"projections": [TOTAL]}, "Y2": {"projections": [MARGIN]}}},
                         "objects": {"valueAxis": props(show="true", labelDisplayUnits="1D", secLabelDisplayUnits="1D")},
                         "visualContainerObjects": {"title": bound_title("ComboTitle")}}},
    "note": {"name": "note", "position": {"x": 0, "y": 360, "width": 200, "height": 28},
             "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": []}}]},
                        "visualContainerObjects": {"title": bound_title("NoteTitle")}}},
    "dates": SLICER,
    # A button's title is off unless the visual turns it on, so its literal text never shows.
    "tab": {"name": "tab", "position": {"x": 220, "y": 360, "width": 100, "height": 28},
            "visual": {"visualType": "actionButton", "visualContainerObjects": {"title": props(text="'Next page'")}}},
}
MEASURES = {
    "total": "\tmeasure 'Total Sales' = SUM(Sales[Amount])\n\t\tformatString: #,##0\n",
    "margin": ("\tmeasure 'Margin %' =\n\t\t\tDIVIDE(\n\t\t\t\tSUM(Sales[Profit]),\n\t\t\t\t[Total Sales],\n"
               "\t\t\t\tBLANK()\n\t\t\t)\n\t\tformatString: 0.0%\n"),
    "average": "\tmeasure 'Average Order' = DIVIDE([Total Sales], [Order Count])\n\t\tformatString: #,##0.00\n",
    "orders": "\tmeasure 'Order Count' = COUNTROWS(Sales)\n\t\tformatString: #,##0\n",
    "top": "\tmeasure 'Top Region' = MAXX ( TOPN ( 1, VALUES ( Sales[Region] ), [Total Sales] ), Sales[Region] )\n",
    "caption": ('\tmeasure \'Top Region Caption\' = IF ( NOT ISBLANK ( [Top Region] ), FORMAT ( [Total Sales], "#,##0" ) '
                '& " | " & [Top Region] )\n'),
    "helper": "\tmeasure _MinOrders = 30\n\t\tformatString: 0\n\t\tisHidden\n",
}


def build(root, report=None, page=None, visuals=None, measures=None):
    """Write the fixture under root; return (report folder, model folder)."""
    rpt, sm = os.path.join(root, "R.Report"), os.path.join(root, "R.SemanticModel")

    def dump(path, data):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f)
    dump(os.path.join(rpt, "definition.pbir"), {"version": "4.0", "datasetReference": {"byPath": {"path": "../R.SemanticModel"}}})
    dump(os.path.join(rpt, "definition", "report.json"), report or REPORT)
    dump(os.path.join(rpt, "definition", "pages", "p1", "page.json"), page or PAGE)
    for v in (visuals or VISUALS).values():
        dump(os.path.join(rpt, "definition", "pages", "p1", "visuals", v["name"], "visual.json"), v)
    os.makedirs(os.path.join(sm, "definition", "tables"))
    with open(os.path.join(sm, "definition", "tables", "Sales.tmdl"), "w", encoding="utf-8") as f:
        f.write("table Sales\n\n" + "\n".join((measures or MEASURES).values()))
    return rpt, sm


def write_style(root, text):
    path = os.path.join(root, "report-style.yaml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    return path


def run(rpt, style, *extra):
    with contextlib.redirect_stdout(io.StringIO()):
        code = cs.main([rpt, "--style", style, *extra])
    return code, [f["check"] for f in cs.findings], dict(cs.summary)


def visual(name, path, value, extra=None):
    """Fixture arguments with one value inside one visual replaced."""
    vs = copy.deepcopy(VISUALS)
    node = vs[name]
    for key in path[:-1]:
        node = node[key]
    node[path[-1]] = value
    vs.update(extra or {})
    return {"visuals": vs}


def measure(key, text):
    return {"measures": dict(MEASURES, **{key: text})}


@unittest.skipUnless(HAVE_YAML, "PyYAML is not installed")
class CheckStyle(unittest.TestCase):
    def test_example_style_on_a_matching_report(self):
        with tempfile.TemporaryDirectory() as root:
            code, found, summary = run(build(root)[0], EXAMPLE)
        self.assertEqual((code, found), (0, []))
        self.assertEqual(set(summary), {"style", "pages", "units", "slicers", "titles", "formats", "blanks", "captions"})

    def test_each_setting_is_caught(self):
        other_group = dict(copy.deepcopy(SLICER), name="dates2", position={"x": 900, "y": 500, "width": 300, "height": 100})
        other_group["visual"]["syncGroup"] = {"groupName": "Other"}
        cases = [
            ("pages", {"page": dict(PAGE, displayOption="FitToWidth")}),
            ("pages", {"page": dict(PAGE, width=1000)}),
            ("pages", {"page": dict(PAGE, height=600)}),
            ("pages", {"page": dict(PAGE, objects={"background": [{"properties": {
                "color": {"solid": {"color": lit("'#000000'")}}, "transparency": lit("0D")}}],
                "outspace": PAGE["objects"]["outspace"]})}),
            ("pages", {"page": dict(PAGE, objects={"background": [{"properties": {
                "color": {"solid": {"color": lit("'#FFFFFF'")}}, "transparency": lit("50D")}}],
                "outspace": PAGE["objects"]["outspace"]})}),
            # The wallpaper: unset, another color, or a color made see-through.
            ("pages", {"page": dict(PAGE, objects={"background": PAGE["objects"]["background"]})}),
            ("pages", {"page": dict(PAGE, objects=dict(PAGE["objects"], outspace=[{"properties": {
                "color": {"solid": {"color": lit("'#F0F0F0'")}}}}]))}),
            ("pages", {"page": dict(PAGE, objects=dict(PAGE["objects"], outspace=[{"properties": {
                "color": {"solid": {"color": lit("'#FFFFFF'")}}, "transparency": lit("100D")}}]))}),
            ("pages", {"report": {"objects": {"outspacePane": props(expanded="true", visible="true")}}}),
            ("pages", {"report": {"objects": {"outspacePane": props(expanded="false", visible="false")}}}),
            ("pages", {"page": dict(PAGE, objects=dict(PAGE["objects"], outspacePane=props(expanded="true")))}),
            ("units", visual("kpi", ["visual", "objects", "labels"], props(labelDisplayUnits="0D"))),
            ("units", visual("trend", ["visual", "objects", "valueAxis"], props(show="true"))),
            ("units", visual("trend", ["visual", "objects", "labels"], props(show="true"))),
            ("units", visual("combo", ["visual", "objects", "valueAxis"], props(show="true", labelDisplayUnits="1D"))),
            ("units", visual("share", ["visual", "objects", "labels"], props(show="true", labelDisplayUnits="1D"))),
            ("slicers", visual("dates", ["visual", "objects", "data"], props(mode="'Relative'"))),
            ("slicers", visual("dates", ["visual", "objects", "slider"], props(show="false"))),
            ("slicers", visual("dates", ["name"], "dates", {"dates2": other_group})),
            ("titles", visual("trend", ["visual", "visualContainerObjects", "title"],
                              props(show="true", text="'Sales by month'"))),
            ("formats", measure("average", "\tmeasure 'Average Order' = [Total Sales]\n\t\tformatString: 0.000\n")),
            ("blanks", measure("total", "\tmeasure 'Total Sales' = COALESCE ( SUM(Sales[Amount]), 0 )\n")),
            ("blanks", measure("margin", "\tmeasure 'Margin %' = DIVIDE ( SUM(Sales[Profit]), [Total Sales], 0 )\n")),
            ("blanks", measure("total", "\tmeasure 'Total Sales' = SUM(Sales[Amount]) + 0\n")),
            ("blanks", measure("top", '\tmeasure \'Top Region\' = IF ( ISBLANK ( [Total Sales] ), "\u2014", "x" )\n')),
            ("blanks", measure("total", "\tmeasure 'Total Sales' = IF ( NOT ISEMPTY ( Sales ), SUM(Sales[Amount]), 0 )\n")),
            ("captions", measure("caption", '\tmeasure \'Top Region Caption\' = [Top Region] & " | " & '
                                            'FORMAT ( [Total Sales], "#,##0" )\n')),
        ]
        for want, change in cases:
            with self.subTest(want=want, change=json.dumps(change, ensure_ascii=False)[:120]):
                with tempfile.TemporaryDirectory() as root:
                    code, found, _ = run(build(root, **change)[0], EXAMPLE)
                    self.assertEqual(code, 1)
                    self.assertTrue(found and set(found) == {want}, found)

    def test_only_listed_settings_are_checked(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, _ = build(root, page=dict(PAGE, displayOption="FitToWidth", width=1000), **visual(
                "trend", ["visual", "visualContainerObjects", "title"], props(show="true", text="'Sales by month'")))
            self.assertEqual(run(rpt, write_style(root, ""))[:2], (0, []))
            code, found, summary = run(rpt, write_style(root, "displayUnits: none\n"))
            self.assertEqual((code, found, set(summary)), (0, [], {"style", "units"}))

    def test_bad_style_file_stops(self):
        for text in ("colour: red\n", "page:\n  view: Fit\n", "page:\n  background: #FFFFFF\n", "displayUnits: lakhs\n",
                     "page:\n  wallpaper: grey\n",
                     "dateSlicer:\n  slider: yes please\n", "formats: '#,##0'\n", "page: 1280\n"):
            with self.subTest(text=text), tempfile.TemporaryDirectory() as root:
                rpt, _ = build(root)
                with self.assertRaises(SystemExit) as e, contextlib.redirect_stderr(io.StringIO()):
                    run(rpt, write_style(root, text))
                self.assertEqual(e.exception.code, 2)

    def test_model_settings_need_a_model(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, sm = build(root, **measure("total", "\tmeasure 'Total Sales' = SUM(Sales[Amount]) + 0\n"))
            os.remove(os.path.join(rpt, "definition.pbir"))  # no byPath reference to find the model
            style = write_style(root, "formats: ['#,##0']\nblanks: keep\ncaptionSeparator: ' | '\n")
            code, found, summary = run(rpt, style)
            self.assertEqual((code, found), (0, []))
            self.assertTrue(all(summary[c].startswith("skipped") for c in ("formats", "blanks", "captions")))
            code, found, _ = run(rpt, style, "--model", sm)
            self.assertEqual((code, sorted(set(found))), (1, ["blanks", "formats"]))


class MeasureHelpers(unittest.TestCase):
    def test_blank_fills_ignores_look_alikes(self):
        for expr in ['DIVIDE ( [A], [B], BLANK () )', 'FORMAT ( [A], "0;-0;0" )', '[Name] & " - " & [Code]',
                     '[A] + 0.5', '10 + [A]', 'IF ( NOT ISBLANK ( [A] ), FORMAT ( [A], "0.0%" ) )',
                     "CALCULATE ( [A], 'My, Table'[B] = \"x,y\" )"]:
            self.assertEqual(cs.blank_fills(expr), [], expr)
        for expr in ['IF ( ISBLANK ( [A] ), "N/A", [A] )', 'DIVIDE ( [A], [B], -1 )', '0 + [A]']:
            self.assertTrue(cs.blank_fills(expr), expr)

    def test_formats_are_exact_or_whole_string_patterns(self):
        self.assertTrue(cs.format_allowed("0.0%", ["0.0%"]))
        self.assertTrue(cs.format_allowed("#,##0.0 \\h", [r"#,##0\.0 \\[a-z]"]))
        self.assertTrue(cs.format_allowed("#,##0.0 \\h", ["#,##0.0 \\h"]))  # not a valid pattern, so compared exactly
        self.assertFalse(cs.format_allowed("0.00", ["0.0", "#,##0"]))


if __name__ == "__main__":
    unittest.main()
