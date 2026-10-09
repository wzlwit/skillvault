"""Tests for scripts/check_visual_conventions.py on a small synthetic PBIR report and TMDL model.

Run from the skill folder: python -m unittest discover -s tests
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
import check_visual_conventions as cvc  # noqa: E402

GDI = cvc.text_width() is not None


def lit(value):
    return {"expr": {"Literal": {"Value": value}}}


def props(**kw):
    return [{"properties": {k: lit(v) for k, v in kw.items()}}]


MEASURES = {
    "total": "\tmeasure 'Total Cases' = SUM(Facts[Cases])\n\t\tformatString: #,##0\n",
    "rate": ("\tmeasure 'Resolved Rate' =\n\t\t\tDIVIDE(\n\t\t\t\tSUM(Facts[Resolved]),\n\t\t\t\t[Total Cases],\n"
             "\t\t\t\tBLANK()\n\t\t\t)\n\t\tformatString: 0.0%;-0.0%;0.0%\n"),
    "hours": "\tmeasure 'Avg Hours' = DIVIDE(SUM(Facts[Seconds]), [Total Cases]) / 3600\n\t\tformatString: #,##0.0 \\h\n",
    "top": "\tmeasure 'Top Queue' = MAXX ( TOPN ( 1, VALUES ( Facts[Queue] ), [Total Cases] ), Facts[Queue] )\n",
    "caption": ('\tmeasure \'Top Queue Caption\' = IF ( NOT ISBLANK ( [Top Queue] ), FORMAT ( [Total Cases], "#,##0", '
                'USERCULTURE () ) & " \u00b7 " & [Top Queue] )\n'),
    "helper": "\tmeasure _MinVolume = 30\n\t\tformatString: 0\n\t\tisHidden\n",
}

PAGE = {"name": "p1", "displayName": "Summary", "displayOption": "FitToWidth",
        "objects": {"background": [{"properties": {"color": {"solid": {"color": lit("'#FAF9F8'")}},
                                                   "transparency": lit("0D")}}]}}
REPORT = {"objects": {"outspacePane": props(expanded="false", visible="true")}}
TOTAL = {"field": {"Measure": {"Expression": {"SourceRef": {"Entity": "Facts"}}, "Property": "Total Cases"}}}
VISUALS = {
    "kpi": {"name": "kpi", "position": {"x": 0, "y": 0, "width": 200, "height": 60},
            "visual": {"visualType": "card", "objects": {"labels": props(labelDisplayUnits="1D")},
                       "visualContainerObjects": {"title": props(show="true", text="'Total cases'", fontSize="10D")}}},
    "donut": {"name": "donut", "position": {"x": 0, "y": 80, "width": 400, "height": 260},
              "visual": {"visualType": "donutChart", "query": {"queryState": {"Y": {"projections": [TOTAL]}}},
                         "objects": {"labels": props(show="true", labelDisplayUnits="1D", percentageLabelPrecision="1D"),
                                     "legend": props(show="true", position="'RightCenter'")},
                         "visualContainerObjects": {"title": props(show="true", text="'SLA scope'", fontSize="11D")}}},
    "trend": {"name": "trend", "position": {"x": 420, "y": 80, "width": 400, "height": 260},
              "visual": {"visualType": "lineChart", "query": {"queryState": {"Y": {"projections": [TOTAL]}}},
                         "objects": {"valueAxis": props(show="true", labelDisplayUnits="1D")},
                         "visualContainerObjects": {"title": props(show="true", text="'Case volume'", fontSize="'11'")}}},
    "note": {"name": "note", "position": {"x": 0, "y": 360, "width": 200, "height": 28},
             "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": []}}]},
                        "visualContainerObjects": {"title": props(show="true", text="'No update in 7 days'",
                                                                  fontSize="10D")}}},
    # A button's title is off unless turned on; its internal name never shows, so it is not measured.
    "tab": {"name": "tab", "position": {"x": 220, "y": 360, "width": 100, "height": 28},
            "visual": {"visualType": "actionButton",
                       "visualContainerObjects": {"title": props(text="'AgentHourlyAvailabilityInactive'")}}},
}


def build(root, report=None, page=None, visuals=None, measures=None):
    """Write the fixture under root; return (report folder, model folder)."""
    rpt, sm = os.path.join(root, "R.Report"), os.path.join(root, "M.SemanticModel")

    def dump(path, data):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f)
    dump(os.path.join(rpt, "definition", "report.json"), report or REPORT)
    dump(os.path.join(rpt, "definition", "pages", "p1", "page.json"), page or PAGE)
    for v in (visuals or VISUALS).values():
        dump(os.path.join(rpt, "definition", "pages", "p1", "visuals", v["name"], "visual.json"), v)
    os.makedirs(os.path.join(sm, "definition", "tables"))
    with open(os.path.join(sm, "definition", "tables", "Facts.tmdl"), "w", encoding="utf-8") as f:
        f.write("table Facts\n\n" + "\n".join((measures or MEASURES).values()))
    return rpt, sm


def run(rpt, sm):
    with contextlib.redirect_stdout(io.StringIO()):
        code = cvc.main([rpt, "--model", sm])
    return code, list(cvc.findings)


class CheckVisualConventions(unittest.TestCase):
    def test_good_report_has_no_findings(self):
        with tempfile.TemporaryDirectory() as root:
            self.assertEqual(run(*build(root)), (0, []))

    def test_each_rule_is_caught(self):
        def visual(name, path, value):
            vs = copy.deepcopy(VISUALS)
            node = vs[name]
            for key in path[:-1]:
                node = node[key]
            node[path[-1]] = value
            return {"visuals": vs}

        def measure(key, text):
            return {"measures": dict(MEASURES, **{key: text})}

        cases = [
            ("PAGES", {"page": dict(PAGE, displayOption="FitToPage")}),
            ("PAGES", {"page": dict(PAGE, objects={"background": [{"properties": {
                "color": {"solid": {"color": lit("'#FFFFFF'")}}, "transparency": lit("0D")}}]})}),
            ("PAGES", {"report": {"objects": {"outspacePane": props(expanded="true", visible="true")}}}),
            ("UNITS", visual("kpi", ["visual", "objects", "labels"], props(labelDisplayUnits="0D"))),
            ("UNITS", visual("donut", ["visual", "objects", "labels"], props(show="true", labelDisplayUnits="1D"))),
            ("UNITS", visual("trend", ["visual", "objects", "valueAxis"], props(show="true"))),
            ("BLANKS", measure("total", "\tmeasure 'Total Cases' = COALESCE ( SUM(Facts[Cases]), 0 )\n")),
            ("BLANKS", measure("rate", "\tmeasure 'Resolved Rate' = DIVIDE ( SUM(Facts[Resolved]), [Total Cases], 0 )\n")),
            ("BLANKS", measure("total", "\tmeasure 'Total Cases' = SUM(Facts[Cases]) + 0\n")),
            ("BLANKS", measure("top", '\tmeasure \'Top Queue\' = IF ( ISBLANK ( [Total Cases] ), "\u2014", "x" )\n')),
            ("BLANKS", measure("total", "\tmeasure 'Total Cases' = IF ( NOT ISEMPTY ( Facts ), SUM(Facts[Cases]), 0 )\n")),
            ("FORMATS", measure("hours", "\tmeasure 'Avg Hours' = SUM(Facts[Seconds]) / 3600\n\t\tformatString: 0.00\n")),
            ("CAPTIONS", measure("caption", '\tmeasure \'Top Queue Caption\' = [Top Queue] & " \u00b7 " & '
                                            'FORMAT ( [Total Cases], "#,##0" )\n')),
        ]
        if GDI:
            cases += [
                ("TEXT", visual("kpi", ["visual", "visualContainerObjects", "title"],
                                props(show="true", text="'Average time to first resolution in hours'", fontSize="10D"))),
                ("TEXT", visual("note", ["visual", "objects", "general"], [{"properties": {"paragraphs": [{"textRuns": []}]}}])),
            ]
        for want, change in cases:
            with self.subTest(want=want, change=json.dumps(change, ensure_ascii=False)[:120]):
                with tempfile.TemporaryDirectory() as root:
                    code, found = run(*build(root, **change))
                    self.assertEqual(code, 1)
                    self.assertTrue(found and all(f.startswith(want + " ") for f in found), found)

    def test_measure_parser(self):
        with tempfile.TemporaryDirectory() as root:
            _, sm = build(root)
            ms = cvc.measures(sm)
        self.assertEqual(set(ms), {"Total Cases", "Resolved Rate", "Avg Hours", "Top Queue", "Top Queue Caption",
                                   "_MinVolume"})
        self.assertIn("BLANK()", ms["Resolved Rate"]["expr"])
        self.assertEqual(ms["Avg Hours"]["format"], "#,##0.0 \\h")
        self.assertTrue(ms["_MinVolume"]["hidden"])
        self.assertFalse(ms["Total Cases"]["hidden"])

    def test_blank_fills_ignores_look_alikes(self):
        for expr in ['DIVIDE ( [A], [B], BLANK () )', 'FORMAT ( [A], "0;-0;0" )', '[Name] & " - " & [Code]',
                     '[A] + 0.5', '10 + [A]', 'IF ( NOT ISBLANK ( [A] ), FORMAT ( [A], "0.0%" ) )',
                     "CALCULATE ( [A], 'My, Table'[B] = \"x,y\" )"]:
            self.assertEqual(cvc.blank_fills(expr), [], expr)
        for expr in ['IF ( ISBLANK ( [A] ), "N/A", [A] )', 'DIVIDE ( [A], [B], -1 )', '0 + [A]']:
            self.assertTrue(cvc.blank_fills(expr), expr)


if __name__ == "__main__":
    unittest.main()
