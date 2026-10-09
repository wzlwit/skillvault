"""Tests for scripts/verify_report.py on a small synthetic PBIR report, its TMDL model and a PBIX built from them.

Run from the skill folder: python -m unittest discover -s tests   (needs pbir-utils; PBIXRay is not needed here)
"""
import contextlib
import copy
import io
import json
import os
import sys
import tempfile
import unittest
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import verify_report as vr  # noqa: E402

try:
    import pbir_utils  # noqa: F401
    HAVE_PBIR_UTILS = True
except ImportError:
    HAVE_PBIR_UTILS = False


def lit(value):
    return {"expr": {"Literal": {"Value": value}}}


def props(**kw):
    return [{"properties": {k: lit(v) for k, v in kw.items()}}]


def bound_title(key):
    return [{"properties": {"show": lit("true"), "text": {"expr": {"Aggregation": {"Expression": {"Column": {
        "Expression": {"SourceRef": {"Entity": "Labels"}}, "Property": key}}, "Function": 3}}}}}]


def measure(name):
    return {"field": {"Measure": {"Expression": {"SourceRef": {"Entity": "Facts"}}, "Property": name}},
            "queryRef": "Facts." + name}


ALT = [{"properties": {"altText": lit("'Description'")}}]
MONTH = {"field": {"Column": {"Expression": {"SourceRef": {"Entity": "Facts"}}, "Property": "Month"}},
         "queryRef": "Facts.Month"}
PAGE = {"name": "p1", "displayName": "Summary", "displayOption": "FitToWidth", "width": 1280, "height": 720,
        "objects": {"background": [{"properties": {"color": {"solid": {"color": lit("'#FAF9F8'")}},
                                                   "transparency": lit("0D")}}]}}
REPORT = {"objects": {"outspacePane": props(expanded="false", visible="true")}}


def card(name, x, y, w, h, title=None, parent=None):
    v = {"name": name, "position": {"x": x, "y": y, "width": w, "height": h},
         "visual": {"visualType": "card", "query": {"queryState": {"Values": {"projections": [measure("Total Cases")]}}},
                    "objects": {"labels": props(labelDisplayUnits="1D")},
                    "visualContainerObjects": {"title": bound_title(title) if title else props(show="false"),
                                               "general": ALT}}}
    if parent:
        v["parentGroupName"] = parent
    return v


VISUALS = {
    "tile": {"name": "tile", "position": {"x": 16, "y": 16, "width": 210, "height": 90},
             "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": []}}]},
                        "visualContainerObjects": {"title": bound_title("TotalCasesTitle")}}},
    "kpi": card("kpi", 20, 30, 200, 42),
    "caption": card("caption", 24, 70, 192, 24),
    "trend": {"name": "trend", "position": {"x": 20, "y": 120, "width": 600, "height": 300},
              "visual": {"visualType": "lineChart",
                         "query": {"queryState": {"Category": {"projections": [MONTH]},
                                                  "Y": {"projections": [measure("Total Cases")]}}},
                         "objects": {"valueAxis": props(show="true", labelDisplayUnits="1D")},
                         "visualContainerObjects": {"title": bound_title("TrendTitle"), "general": ALT}}},
    "donut": {"name": "donut", "position": {"x": 640, "y": 120, "width": 400, "height": 300},
              "visual": {"visualType": "donutChart", "query": {"queryState": {"Y": {"projections": [measure("Total Cases")]}}},
                         "objects": {"labels": props(show="true", labelDisplayUnits="1D", percentageLabelPrecision="1D")},
                         "visualContainerObjects": {"title": bound_title("DonutTitle"), "general": ALT}}},
    "group": {"name": "group", "position": {"x": 20, "y": 440, "width": 600, "height": 200},
              "visualGroup": {"displayName": "Group", "groupMode": "ScaleMode"}},
    "child": card("child", 10, 10, 200, 60, parent="group"),
    "button": {"name": "button", "position": {"x": 1100, "y": 20, "width": 120, "height": 32},
               "visual": {"visualType": "actionButton"}},
}
TMDL = {
    "Facts": "table Facts\n\n\tmeasure 'Total Cases' = SUM(Facts[Cases])\n\t\tformatString: #,##0\n\n"
             "\tcolumn Month\n\t\tdataType: string\n\n\tcolumn Cases\n\t\tdataType: int64\n",
    "Labels": "table Labels\n\n\tcolumn TotalCasesTitle\n\n\tcolumn TrendTitle\n\n\tcolumn DonutTitle\n",
}


def dump(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)


def build(root, report=None, page=None, visuals=None, tmdl=None):
    """Write the fixture; return (report folder, model folder)."""
    rpt, sm = os.path.join(root, "R.Report"), os.path.join(root, "R.SemanticModel")
    dump(os.path.join(rpt, "definition.pbir"), {"version": "4.0", "datasetReference": {"byPath": {"path": "../R.SemanticModel"}}})
    dump(os.path.join(rpt, "definition", "report.json"), report or REPORT)
    dump(os.path.join(rpt, "definition", "pages", "p1", "page.json"), page or PAGE)
    for v in (visuals or VISUALS).values():
        dump(os.path.join(rpt, "definition", "pages", "p1", "visuals", v["name"], "visual.json"), v)
    for table, text in (tmdl or TMDL).items():
        os.makedirs(os.path.join(sm, "definition", "tables"), exist_ok=True)
        with open(os.path.join(sm, "definition", "tables", table + ".tmdl"), "w", encoding="utf-8") as f:
            f.write(text)
    return rpt, sm


def pack(rpt, pbix):
    """A PBIX-like zip holding the report as Desktop stores PBIR in a PBIX (Report/definition/...); no model."""
    with zipfile.ZipFile(pbix, "w") as z:
        for d, _, files in os.walk(os.path.join(rpt, "definition")):
            for f in files:
                full = os.path.join(d, f)
                z.write(full, "Report/" + os.path.relpath(full, rpt).replace("\\", "/"))
    return pbix


def run(*argv):
    with contextlib.redirect_stdout(io.StringIO()):
        code = vr.main(list(argv))
    return code, [(f["check"], f["severity"]) for f in vr.findings], dict(vr.summary)


def changed(**kw):
    """Fixture arguments with one visual (or the page/report) changed."""
    vs = copy.deepcopy(VISUALS)
    for name, update in kw.pop("visuals", {}).items():
        vs[name] = update(copy.deepcopy(vs[name]))
    return dict(visuals=vs, **kw)


@unittest.skipUnless(HAVE_PBIR_UTILS, "pbir-utils is not installed")
class VerifyReport(unittest.TestCase):
    def test_good_report_passes(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, _ = build(root)
            code, found, summary = run(rpt)
            self.assertEqual((code, found), (0, []))
            self.assertIn("5 fields checked", summary["bindings"])  # Total Cases, Month and three title keys

    def test_pbix_with_report_parity(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, sm = build(root)
            pbix = pack(rpt, os.path.join(root, "R.pbix"))
            self.assertEqual(run(pbix, "--model", sm, "--against", rpt)[:2], (0, []))
            with open(os.path.join(rpt, "definition", "pages", "p1", "page.json"), "a", encoding="utf-8") as f:
                f.write(" ")
            code, found, _ = run(pbix, "--checks", "none", "--against", rpt)
            self.assertEqual((code, found), (1, [("parity", "error")]))

    def test_each_error_is_caught(self):
        def move(**pos):
            return lambda v: dict(v, position=dict(v["position"], **pos))

        def drop(obj, key):
            def f(v):
                v["visual"]["objects"][obj] = [{"properties": {k: x for k, x in v["visual"]["objects"][obj][0]["properties"].items()
                                                               if k != key}}]
                return v
            return f

        def bind(kind, entity, prop):
            def f(v):
                field = {kind: {"Expression": {"SourceRef": {"Entity": entity}}, "Property": prop}}
                v["visual"]["query"]["queryState"]["Y"]["projections"] = [{"field": field, "queryRef": entity + "." + prop}]
                return v
            return f

        cases = [
            ("rules", {"page": dict(PAGE, displayOption="FitToPage")}),
            ("rules", {"page": dict(PAGE, objects={"background": [{"properties": {
                "color": {"solid": {"color": lit("'#FFFFFF'")}}, "transparency": lit("0D")}}]})}),
            ("rules", {"report": {"objects": {"outspacePane": props(expanded="true", visible="true")}}}),
            ("rules", changed(visuals={"kpi": drop("labels", "labelDisplayUnits")})),
            ("rules", changed(visuals={"trend": drop("valueAxis", "labelDisplayUnits")})),
            ("rules", changed(visuals={"donut": drop("labels", "percentageLabelPrecision")})),
            ("geometry", changed(visuals={"trend": move(x=900)})),
            ("geometry", changed(visuals={"trend": move(x=500)})),
            ("geometry", changed(visuals={"child": move(y=650)})),  # inside the page and clear on its own; off it at group y 440
            ("bindings", changed(visuals={"trend": bind("Measure", "Facts", "Total Casez")})),
            ("bindings", changed(visuals={"trend": bind("Column", "Facts", "Missing")})),
            ("bindings", changed(visuals={"donut": lambda v: dict(v, visual=dict(v["visual"], visualContainerObjects=dict(
                v["visual"]["visualContainerObjects"], title=bound_title("MissingTitle"))))})),
        ]
        for check, change in cases:
            with self.subTest(check=check, change=json.dumps(change)[:140]):
                with tempfile.TemporaryDirectory() as root:
                    rpt, _ = build(root, **change)
                    code, found, _ = run(rpt)
                    self.assertEqual(code, 1)
                    self.assertTrue(found and set(found) == {(check, "error")}, found)

    def test_warnings_fail_only_with_strict(self):
        literal = lambda v: dict(v, visual=dict(v["visual"], visualContainerObjects=dict(  # noqa: E731
            v["visual"]["visualContainerObjects"], title=props(show="true", text="'Case volume'"))))
        no_alt = lambda v: dict(v, visual=dict(v["visual"], visualContainerObjects={  # noqa: E731
            "title": v["visual"]["visualContainerObjects"]["title"]}))
        over = lambda v: dict(v, position=dict(v["position"], x=500, y=200))  # noqa: E731
        for check, change in [("rules", changed(visuals={"trend": literal})), ("rules", changed(visuals={"trend": no_alt})),
                              ("geometry", changed(visuals={"button": over}))]:
            with self.subTest(check=check):
                with tempfile.TemporaryDirectory() as root:
                    rpt, _ = build(root, **change)
                    code, found, _ = run(rpt)
                    self.assertEqual((code, set(found)), (0, {(check, "warning")}))
                    self.assertEqual(run(rpt, "--strict")[0], 1)

    def test_legacy_pbix_is_refused(self):
        with tempfile.TemporaryDirectory() as root:
            pbix = os.path.join(root, "Old.pbix")
            with zipfile.ZipFile(pbix, "w") as z:
                z.writestr("Report/Layout", "{}")
            with self.assertRaises(SystemExit) as e, contextlib.redirect_stdout(io.StringIO()):
                vr.main([pbix])
            self.assertIn("legacy Layout", str(e.exception))

    def test_field_refs_resolve_filter_aliases(self):
        found = set()
        vr.field_refs({"filterConfig": {"filters": [{"filter": {
            "From": [{"Name": "d", "Entity": "DimDate", "Type": 0}],
            "Where": [{"Condition": {"Comparison": {"Left": {"Column": {
                "Expression": {"SourceRef": {"Source": "d"}}, "Property": "Date"}}}}}]}}]}}, found)
        self.assertEqual(found, {("Column", "DimDate", "Date")})


if __name__ == "__main__":
    unittest.main()
