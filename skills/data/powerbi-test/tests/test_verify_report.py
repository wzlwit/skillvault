"""Tests for scripts/verify_report.py on a small synthetic PBIR report, its TMDL model and a PBIX-like zip built from them.

Run from the skill folder: python -m unittest discover -s tests   (needs pbir-utils for the rules; not PBIXRay)
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
GDI = vr.text_width() is not None


def lit(value):
    return {"expr": {"Literal": {"Value": value}}}


def props(**kw):
    return [{"properties": {k: lit(v) for k, v in kw.items()}}]


def bound_title(key):
    return [{"properties": {"show": lit("true"), "text": {"expr": {"Aggregation": {"Expression": {"Column": {
        "Expression": {"SourceRef": {"Entity": "Texts"}}, "Property": key}}, "Function": 3}}}}}]


def measure(name):
    return {"field": {"Measure": {"Expression": {"SourceRef": {"Entity": "Sales"}}, "Property": name}},
            "queryRef": "Sales." + name}


ALT = [{"properties": {"altText": lit("'Description'")}}]
MONTH = {"field": {"Column": {"Expression": {"SourceRef": {"Entity": "Sales"}}, "Property": "Month"}},
         "queryRef": "Sales.Month"}
PAGE = {"name": "p1", "displayName": "Summary", "displayOption": "FitToPage", "width": 1280, "height": 720}
REPORT = {}
RESX = {"SalesTitle": "Sales", "TrendTitle": "Sales by month", "ShareTitle": "Share of sales"}


def card(name, x, y, w, h, parent=None):
    v = {"name": name, "position": {"x": x, "y": y, "width": w, "height": h},
         "visual": {"visualType": "card", "query": {"queryState": {"Values": {"projections": [measure("Total Sales")]}}},
                    "visualContainerObjects": {"title": props(show="false"), "general": ALT}}}
    if parent:
        v["parentGroupName"] = parent
    return v


VISUALS = {
    "tile": {"name": "tile", "position": {"x": 16, "y": 16, "width": 210, "height": 90},
             "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": []}}]},
                        "visualContainerObjects": {"title": bound_title("SalesTitle")}}},
    "kpi": card("kpi", 20, 30, 200, 42),
    "caption": card("caption", 24, 70, 192, 24),
    "trend": {"name": "trend", "position": {"x": 20, "y": 120, "width": 600, "height": 300},
              "visual": {"visualType": "lineChart",
                         "query": {"queryState": {"Category": {"projections": [MONTH]},
                                                  "Y": {"projections": [measure("Total Sales")]}}},
                         "visualContainerObjects": {"title": bound_title("TrendTitle"), "general": ALT}}},
    "share": {"name": "share", "position": {"x": 640, "y": 120, "width": 400, "height": 300},
              "visual": {"visualType": "donutChart", "query": {"queryState": {"Y": {"projections": [measure("Total Sales")]}}},
                         "objects": {"legend": props(show="true", position="'RightCenter'")},
                         "visualContainerObjects": {"title": bound_title("ShareTitle"), "general": ALT}}},
    "group": {"name": "group", "position": {"x": 20, "y": 440, "width": 600, "height": 200},
              "visualGroup": {"displayName": "Group", "groupMode": "ScaleMode"}},
    "child": card("child", 10, 10, 200, 60, parent="group"),
    # A range slicer: Between, slider on, 100 px tall, start before end (no query, so it adds no bindings).
    "dates": {"name": "dates", "position": {"x": 700, "y": 440, "width": 330, "height": 100},
              "visual": {"visualType": "slicer", "objects": {
                  "data": props(mode="'Between'", startDate="datetime'2025-01-01T00:00:00'",
                                endDate="datetime'2025-12-31T00:00:00'"),
                  "slider": props(show="true")}}},
    "button": {"name": "button", "position": {"x": 1100, "y": 20, "width": 120, "height": 32},
               "visual": {"visualType": "actionButton"}},
    # A one-line note: a titled textbox with no paragraph, so no scrollbar.
    "note": {"name": "note", "position": {"x": 1100, "y": 60, "width": 160, "height": 28},
             "visual": {"visualType": "textbox", "objects": {"general": [{"properties": {"paragraphs": []}}]},
                        "visualContainerObjects": {"title": props(show="true", text="'Updated daily'")}}},
}
TMDL = {
    "Sales": "table Sales\n\n\tmeasure 'Total Sales' = SUM(Sales[Amount])\n\t\tformatString: #,##0\n\n"
             "\tcolumn Month\n\t\tdataType: string\n\n\tcolumn Amount\n\t\tdataType: int64\n",
    "Texts": "table Texts\n\n\tcolumn SalesTitle\n\n\tcolumn TrendTitle\n\n\tcolumn ShareTitle\n",
}


def dump(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f)


def build(root, report=None, page=None, visuals=None, tmdl=None):
    """Write the fixture; return (report folder, model folder)."""
    rpt, sm = os.path.join(root, "R.Report"), os.path.join(root, "R.SemanticModel")
    dump(os.path.join(rpt, "definition.pbir"), {"version": "4.0", "datasetReference": {"byPath": {"path": "../R.SemanticModel"}}})
    dump(os.path.join(rpt, "definition", "report.json"), REPORT if report is None else report)
    dump(os.path.join(rpt, "definition", "pages", "p1", "page.json"), page or PAGE)
    for v in (visuals or VISUALS).values():
        dump(os.path.join(rpt, "definition", "pages", "p1", "visuals", v["name"], "visual.json"), v)
    for table, text in (tmdl or TMDL).items():
        os.makedirs(os.path.join(sm, "definition", "tables"), exist_ok=True)
        with open(os.path.join(sm, "definition", "tables", table + ".tmdl"), "w", encoding="utf-8") as f:
            f.write(text)
    return rpt, sm


def write_resx(root, entries=None):
    path = os.path.join(root, "Texts.resx")
    with open(path, "w", encoding="utf-8") as f:
        f.write("<root>%s</root>" % "".join('<data name="%s"><value>%s</value></data>' % kv
                                            for kv in (entries or RESX).items()))
    return path


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
    """Fixture arguments with some visuals changed: visuals={name: function(visual) -> visual}."""
    vs = copy.deepcopy(VISUALS)
    for name, update in kw.pop("visuals", {}).items():
        vs[name] = update(copy.deepcopy(vs[name]))
    return dict(visuals=vs, **kw)


def move(**pos):
    return lambda v: dict(v, position=dict(v["position"], **pos))


def objects(**objs):
    return lambda v: dict(v, visual=dict(v["visual"], objects=dict(v["visual"].get("objects", {}), **objs)))


def container(**objs):
    return lambda v: dict(v, visual=dict(v["visual"], visualContainerObjects=objs))


def bind(kind, entity, prop):
    def f(v):
        field = {kind: {"Expression": {"SourceRef": {"Entity": entity}}, "Property": prop}}
        v["visual"]["query"]["queryState"]["Y"]["projections"] = [{"field": field, "queryRef": entity + "." + prop}]
        return v
    return f


@unittest.skipUnless(HAVE_PBIR_UTILS, "pbir-utils is not installed")
class VerifyReport(unittest.TestCase):
    def test_good_report_passes(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, _ = build(root)
            code, found, summary = run(rpt)
            self.assertEqual((code, found), (0, []))
            self.assertIn("5 fields checked", summary["bindings"])  # Total Sales, Month and three title keys
            self.assertIn("generic 4 passed, 0 failed", summary["rules"])
            if GDI:
                self.assertIn("3 bound titles not measured", summary["text"])
                code, found, summary = run(rpt, "--resx", write_resx(root))
                self.assertEqual((code, found), (0, []))
                self.assertNotIn("not measured", summary["text"])

    def test_pbix_report_parity(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, sm = build(root)
            pbix = pack(rpt, os.path.join(root, "R.pbix"))
            self.assertEqual(run(pbix, "--model", sm, "--against", rpt)[:2], (0, []))
            with open(os.path.join(rpt, "definition", "pages", "p1", "page.json"), "a", encoding="utf-8") as f:
                f.write(" ")
            code, found, _ = run(pbix, "--checks", "none", "--against", rpt)
            self.assertEqual((code, found), (1, [("parity", "error")]))

    def test_each_error_is_caught(self):
        cases = [
            ("geometry", changed(visuals={"trend": move(x=900)})),  # off the page and over the donut
            ("geometry", changed(visuals={"trend": move(x=500)})),
            ("geometry", changed(visuals={"child": move(y=650)})),  # inside the page on its own; off it at group y 440
            ("geometry", changed(visuals={"child": move(x=1070)})),  # and off it at group x 20
            ("bindings", changed(visuals={"trend": bind("Measure", "Sales", "Total Salez")})),
            ("bindings", changed(visuals={"trend": bind("Column", "Sales", "Missing")})),
            ("bindings", changed(visuals={"share": container(title=bound_title("MissingTitle"), general=ALT)})),
        ]
        for check, change in cases:
            with self.subTest(check=check, change=json.dumps(change)[:140]):
                with tempfile.TemporaryDirectory() as root:
                    rpt, _ = build(root, **change)
                    code, found, _ = run(rpt)
                    self.assertEqual(code, 1)
                    self.assertTrue(found and set(found) == {(check, "error")}, found)

    def test_warnings_fail_only_with_strict(self):
        cases = [
            ("rules", changed(visuals={"dates": move(height=85)})),
            ("rules", changed(visuals={"dates": objects(data=props(
                mode="'Between'", startDate="datetime'2026-01-01T00:00:00'", endDate="datetime'2025-12-31T00:00:00'"))})),
            ("rules", changed(visuals={"trend": container(title=bound_title("TrendTitle"))})),  # no alt text
            ("rules", {"page": dict(PAGE, displayName="Page 1")}),
            ("geometry", changed(visuals={"button": move(x=500, y=200)})),
        ]
        if GDI:
            cases += [
                ("text", changed(visuals={"kpi": container(title=props(
                    show="true", text="'Average order value across every region this year'"), general=ALT)})),
                ("text", changed(visuals={"note": objects(general=[{"properties": {"paragraphs": [{"textRuns": []}]}}])})),
                ("text", changed(visuals={"share": lambda v: dict(v, visual=dict(v["visual"], query={"queryState": {"Y": {
                    "projections": [dict(measure("Total Sales"), displayName="Revenue from repeat customers")]}}}))})),
            ]
        for check, change in cases:
            with self.subTest(check=check, change=json.dumps(change, default=str)[:140]):
                with tempfile.TemporaryDirectory() as root:
                    rpt, _ = build(root, **change)
                    code, found, _ = run(rpt)
                    self.assertEqual((code, set(found)), (0, {(check, "warning")}))
                    self.assertEqual(run(rpt, "--strict")[0], 1)

    def test_slider_hidden_or_relative_mode_is_not_flagged(self):
        """Hiding the slider or using another mode is a style choice, so the generic rule lets it pass."""
        for change in (objects(slider=props(show="false")), objects(data=props(mode="'Relative'"))):
            with tempfile.TemporaryDirectory() as root:
                rpt, _ = build(root, **changed(visuals={"dates": lambda v: change(move(height=60)(v))}))
                self.assertEqual(run(rpt)[:2], (0, []))

    def test_project_rule_pack_runs_after_the_generic_one(self):
        with tempfile.TemporaryDirectory() as root:
            pack_file = os.path.join(root, "team-rules.yaml")
            with open(pack_file, "w", encoding="utf-8") as f:
                f.write("rules: [page_width]\ndefinitions:\n  page_width:\n    description: Pages are 1000 px wide\n"
                        "    severity: error\n    scope: page\n    expression: page.get('width') == 1000\n")
            rpt, _ = build(root, **changed(visuals={"trend": container(title=bound_title("TrendTitle"))}))
            code, found, summary = run(rpt, "--rules", pack_file)
            self.assertEqual((code, sorted(found)), (1, [("rules", "error"), ("rules", "warning")]))
            self.assertIn("team-rules.yaml 0 passed, 1 failed", summary["rules"])

    def test_json_output(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, _ = build(root, **changed(visuals={"trend": move(x=500)}))
            out = io.StringIO()
            with contextlib.redirect_stdout(out):
                code = vr.main([rpt, "--checks", "geometry", "--json"])
            result = json.loads(out.getvalue())
            self.assertEqual((code, result["failed"]), (1, True))
            self.assertEqual({f["check"] for f in result["findings"]}, {"geometry"})

    def test_generic_rules_never_raise(self):
        """pbir-utils skips a visual whose expression raises, so a broken rule would pass silently."""
        try:
            from pbir_utils.rule_config import load_rules
            from pbir_utils.rule_engine import _safe_eval, load_pbir_context
        except ImportError:
            self.skipTest("pbir-utils internals changed")
        with tempfile.TemporaryDirectory() as root:
            rpt, _ = build(root)
            ctx = load_pbir_context(rpt)
            for rule in load_rules(config_path=vr.GENERIC_RULES).rules:
                for page in ctx["pages"]:
                    items = page["visuals"] if rule.scope == "visual" else [None]
                    for visual in items:
                        with self.subTest(rule=rule.id, visual=(visual or {}).get("name")):
                            _safe_eval(rule.expression, {**ctx, **rule.params, "page": page, "visual": visual})


class VerifyReportParts(unittest.TestCase):
    """Parts that need neither pbir-utils nor PBIXRay."""

    def test_legacy_inputs_are_refused(self):
        with tempfile.TemporaryDirectory() as root:
            pbix = os.path.join(root, "Old.pbix")
            with zipfile.ZipFile(pbix, "w") as z:
                z.writestr("Report/Layout", "{}")
            folder = os.path.join(root, "Old.Report")
            dump(os.path.join(folder, "report.json"), {})
            for path in (pbix, folder):
                err = io.StringIO()
                with self.assertRaises(SystemExit) as e, contextlib.redirect_stderr(err):
                    vr.main([path])
                self.assertEqual(e.exception.code, 2)
                self.assertIn("PBIR-Legacy", err.getvalue())

    def test_broken_json_stops(self):
        with tempfile.TemporaryDirectory() as root:
            rpt, _ = build(root)
            with open(os.path.join(rpt, "definition", "pages", "p1", "visuals", "trend", "visual.json"), "w") as f:
                f.write("{not json")
            err = io.StringIO()
            with self.assertRaises(SystemExit) as e, contextlib.redirect_stderr(err):
                vr.main([rpt])
            self.assertEqual(e.exception.code, 2)
            self.assertIn("not valid JSON", err.getvalue())

    def test_model_parity(self):
        with tempfile.TemporaryDirectory() as root:
            _, sm = build(root)
            vr.findings.clear()
            vr.check_model_parity({("Sales", "Total Sales"): "\n  SUM(Sales[Amount])  \n"}, sm)  # whitespace aside
            self.assertEqual(vr.findings, [])
            vr.check_model_parity({("Sales", "Total Sales"): "SUM(Sales[Price])", ("Sales", "Orders"): "1"}, sm)
            self.assertEqual([f["where"] for f in vr.findings], ["Sales[Orders]", "Sales[Total Sales]"])

    def test_tmdl_measure_parser(self):
        text = ("table 'Sales Facts'\n\n"
                "\tmeasure Total = SUM('Sales Facts'[Amount])\n\t\tformatString: #,##0\n\n"
                "\tmeasure 'Margin %' =\n\t\t\tDIVIDE(\n\t\t\t\t[Profit],\n\t\t\t\t[Total]\n\t\t\t)\n"
                "\t\tformatString: \"0.0%\"\n\n"
                "\tmeasure Block = ```\n\t\t\tVAR x = 1\n\t\t\tRETURN x\n\t\t\t```\n\t\tisHidden\n")
        with tempfile.TemporaryDirectory() as root:
            _, sm = build(root, tmdl={"Sales Facts": text})
            ms = vr.tmdl_measures(sm)
        self.assertEqual(set(ms), {("Sales Facts", "Total"), ("Sales Facts", "Margin %"), ("Sales Facts", "Block")})
        self.assertIn("[Profit]", ms[("Sales Facts", "Margin %")]["expr"])
        self.assertEqual(ms[("Sales Facts", "Margin %")]["format"], "0.0%")
        self.assertIn("RETURN x", ms[("Sales Facts", "Block")]["expr"])
        self.assertTrue(ms[("Sales Facts", "Block")]["hidden"])
        self.assertFalse(ms[("Sales Facts", "Total")]["hidden"])

    def test_field_refs_resolve_filter_aliases(self):
        found = set()
        vr.field_refs({"filterConfig": {"filters": [{"filter": {
            "From": [{"Name": "d", "Entity": "Date", "Type": 0}],
            "Where": [{"Condition": {"Comparison": {"Left": {"Column": {
                "Expression": {"SourceRef": {"Source": "d"}}, "Property": "Day"}}}}}]}}]}}, found)
        self.assertEqual(found, {("Column", "Date", "Day")})


if __name__ == "__main__":
    unittest.main()
