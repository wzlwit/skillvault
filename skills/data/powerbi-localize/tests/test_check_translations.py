"""Tests for scripts/check_translations.py. Run from the skill folder: python -m unittest discover -s tests"""
import contextlib
import io
import json
import os
import shutil
import sys
import unittest
from xml.sax.saxutils import escape, quoteattr

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "scripts"))
import check_translations as ct  # noqa: E402


def tabs(text):
    """Write TMDL fixtures with four spaces per level; this turns each leading group of four into a tab."""
    out = []
    for line in text.strip("\n").splitlines():
        body = line.lstrip(" ")
        out.append("\t" * ((len(line) - len(body)) // 4) + body)
    return "\n".join(out) + "\n"


def resx(*entries):
    rows = "".join('  <data name=%s xml:space="preserve">\n    <value>%s</value>\n  </data>\n'
                   % (quoteattr(name), escape(value)) for name, value in entries)
    return ('<?xml version="1.0" encoding="utf-8"?>\n<root>\n'
            '  <resheader name="resmimetype">\n    <value>text/microsoft-resx</value>\n  </resheader>\n'
            + rows + "</root>\n")


MODEL = {
    "model.tmdl": tabs("""
model Model
    culture: en-US
    defaultPowerBIDataSourceVersion: powerBI_V3

ref table Sales
ref table Region
ref table Helper
ref table 'Report Text'
ref table Language

ref cultureInfo en-US
ref cultureInfo de-DE
ref cultureInfo fr-FR
"""),
    "tables/Sales.tmdl": tabs("""
table Sales
    lineageTag: 0a0a

    /// Sum of the order amounts
    measure 'Total Sales' = SUM ( Sales[Amount] )
        formatString: #,##0

    measure 'Order Count' =
            VAR n = COUNTROWS ( Sales )
            measure Fake = 1
            RETURN n
        formatString: #,##0

    measure _Helper = 1
        isHidden

    measure 'Fenced Measure' = ```
            column Fake2
            1
            ```
        formatString: 0

    column Amount
        dataType: double
        isHidden
        sourceColumn: Amount

        annotation SummarizationSetBy = Automatic

    column Region
        dataType: string
        sourceColumn: Region

    partition Sales = m
        mode: import
        source =
                let
                    table Fake3
                in
                    Source
"""),
    "tables/Region.tmdl": tabs("""
table Region

    column Country
        dataType: string
        sourceColumn: Country

    column City
        dataType: string
        sourceColumn: City

    hierarchy Geography

        level Country
            column: Country

        level City
            column: City
"""),
    "tables/Helper.tmdl": tabs("""
table Helper
    isHidden

    column Key
        dataType: int64
        sourceColumn: Key

    measure 'Helper Count' = COUNTROWS ( Helper )
"""),
    "tables/Report Text.tmdl": tabs("""
table 'Report Text'
    isHidden

    column Culture
        dataType: string
        sourceColumn: Culture

    column 'Sales by region'
        dataType: string
        sourceColumn: Sales by region
"""),
    "tables/Language.tmdl": tabs("""
table Language
    isHidden

    column Code
        dataType: string
        sourceColumn: Code
"""),
    "relationships.tmdl": tabs("""
relationship 0001
    fromColumn: 'Report Text'.Culture
    toColumn: Language.Code

relationship 0002
    fromColumn: Sales.Region
    toColumn: Region.City
"""),
    "cultures/en-US.tmdl": tabs("""
cultureInfo en-US

    linguisticMetadata =
            {
              "Version": "1.0.0",
              "Language": "en-US"
            }
        contentType: json
"""),
    "cultures/de-DE.tmdl": tabs("""
cultureInfo de-DE

    translations

        model Model

            table Sales
                caption: Umsatz

                measure 'Total Sales'
                    caption: Gesamtumsatz

                measure 'Order Count'
                    caption: Anzahl Bestellungen

                measure 'Fenced Measure'
                    caption: Testkennzahl

                column Region
                    caption: Region

            table Region
                caption: Gebiet

                column Country
                    caption: Land

                column City
                    caption: Stadt

                hierarchy Geography
                    caption: Geografie

                    level Country
                        caption: Land

                    level City
                        caption: Stadt
"""),
    "cultures/fr-FR.tmdl": tabs("""
cultureInfo fr-FR

    translations

        model Model

            table Sales
                caption: Ventes

                measure 'Total Sales'
                    caption: Ventes totales

                column Region
                    caption: Région

            table Region
                caption: Zone
"""),
}

STRINGS = {
    "Strings.en-US.resx": resx(("Total Sales", "Total Sales"), ("Sales by region", "Sales by region"),
                               ("Profit & Loss", "Profit & Loss")),
    "Strings.de-DE.resx": resx(("Total Sales", "Gesamtumsatz"), ("Sales by region", "Umsatz nach Gebiet"),
                               ("Profit & Loss", "Gewinn und Verlust")),
    "Strings.fr-FR.resx": resx(("Total Sales", "Ventes totales"), ("Sales by region", "Ventes par zone"),
                               ("Profit & Loss", "Pertes et profits")),
}


def variant(files, changes=None, remove=()):
    out = {k: v for k, v in files.items() if k not in remove}
    out.update(changes or {})
    return out


def model_findings(files):
    model = ct.analyze_model(files)
    findings = list(model.findings)
    ct.check_model(model, findings)
    return model, findings


def resx_findings(files, base="en-US", allow_pending=False):
    sets, findings = ct.analyze_resx(files)
    coverage = ct.check_resx(sets, base, allow_pending, findings)
    return sets, coverage, findings


def checks(findings, severity=None):
    return sorted({f["check"] for f in findings if severity in (None, f["severity"])})


def only(findings, check):
    matches = [f for f in findings if f["check"] == check]
    if len(matches) != 1:
        raise AssertionError("expected one %s finding, got %r" % (check, matches))
    return matches[0]


class ParsingTests(unittest.TestCase):
    def test_expression_bodies_and_descriptions_are_not_structure(self):
        lines = [content for _, _, content, _ in ct.structural_lines(MODEL["tables/Sales.tmdl"])]
        self.assertIn("measure 'Order Count' =", lines)
        self.assertIn("formatString: 0", lines)
        for fake in ("measure Fake = 1", "column Fake2", "table Fake3", "/// Sum of the order amounts"):
            self.assertNotIn(fake, lines)

    def test_names_and_values_are_unquoted(self):
        self.assertEqual(ct.unquote("'Owner''s Total'"), "Owner's Total")
        self.assertEqual(ct.unquote("Sales"), "Sales")
        self.assertEqual(ct.text_value(' "  Total ""net"" " '), '  Total "net" ')
        self.assertEqual(ct.text_value("  Ventes  "), "Ventes")

    def test_resource_file_names_split_into_set_and_culture(self):
        self.assertEqual(ct.split_resx_name("Strings.fr-FR.resx"), ("Strings", "fr-FR"))
        self.assertEqual(ct.split_resx_name("App.Labels.zh-Hans.resx"), ("App.Labels", "zh-Hans"))
        self.assertEqual(ct.split_resx_name("Strings.es-419.resx"), ("Strings", "es-419"))
        self.assertEqual(ct.split_resx_name("Strings.resx"), ("Strings", ""))
        self.assertEqual(ct.split_resx_name("App.UI.resx"), ("App.UI", ""))


class ModelTests(unittest.TestCase):
    def test_good_model_has_no_errors_and_counts_coverage(self):
        model, findings = model_findings(MODEL)
        self.assertEqual(checks(findings, "error"), [])
        self.assertEqual(checks(findings, "warning"), [])
        coverage = ct.model_coverage(model)
        self.assertTrue(coverage["en-US"]["base"])
        self.assertEqual(coverage["en-US"]["missing"], [])
        self.assertEqual((coverage["de-DE"]["translated"], coverage["de-DE"]["translatable"]), (11, 11))
        fr = coverage["fr-FR"]
        self.assertEqual((fr["translated"], fr["translatable"]), (4, 11))
        self.assertEqual(fr["byKind"], {"table": [2, 2], "column": [1, 3], "measure": [1, 3], "hierarchy": [0, 1],
                                        "level": [0, 2]})
        self.assertIn("level Region[Geography][City]", fr["missing"])
        self.assertIn("measure Sales[Order Count]", fr["missing"])

    def test_hidden_objects_and_children_of_hidden_tables_are_not_translatable(self):
        model = ct.analyze_model(MODEL)
        missing = ct.model_coverage(model)["fr-FR"]["missing"]
        for hidden in ("column Sales[Amount]", "measure Sales[_Helper]", "measure Helper[Helper Count]",
                       "table Helper", "column Report Text[Sales by region]"):
            self.assertNotIn(hidden, missing)
        hierarchy = MODEL["tables/Region.tmdl"].replace("\thierarchy Geography\n", "\thierarchy Geography\n\t\tisHidden\n")
        model = ct.analyze_model(variant(MODEL, {"tables/Region.tmdl": hierarchy}))
        self.assertEqual(ct.model_coverage(model)["de-DE"]["byKind"]["level"], [0, 0])

    def test_a_ref_without_a_culture_file_is_an_error(self):
        _, findings = model_findings(variant(MODEL, remove=["cultures/fr-FR.tmdl"]))
        self.assertIn("fr-FR", only(findings, "culture-ref")["message"])
        self.assertEqual(only(findings, "culture-ref")["severity"], "error")

    def test_culture_files_without_refs_are_only_info(self):
        model_tmdl = MODEL["model.tmdl"].replace("ref cultureInfo fr-FR\n", "")
        _, findings = model_findings(variant(MODEL, {"model.tmdl": model_tmdl}))
        f = only(findings, "culture-ref")
        self.assertEqual((f["severity"], f["items"]), ("info", ["cultures/fr-FR.tmdl"]))

    def test_linguistic_metadata_before_translations_warns(self):
        before = tabs("""
cultureInfo fr-FR

    linguisticMetadata =
            {
              "Version": "1.0.0"
            }
        contentType: json

    translations

        model Model

            table Sales
                caption: Ventes
""")
        model, findings = model_findings(variant(MODEL, {"cultures/fr-FR.tmdl": before}))
        self.assertEqual(only(findings, "culture-linguistic")["severity"], "warning")
        self.assertEqual(ct.model_coverage(model)["fr-FR"]["translated"], 1)
        after = MODEL["cultures/fr-FR.tmdl"] + "\n\tlinguisticMetadata =\n\t\t\t{}\n\t\tcontentType: json\n"
        _, findings = model_findings(variant(MODEL, {"cultures/fr-FR.tmdl": after}))
        self.assertEqual(only(findings, "culture-linguistic")["severity"], "info")

    def test_translation_for_a_missing_object_is_an_error(self):
        text = MODEL["cultures/fr-FR.tmdl"] + ("\t\t\ttable Orders\n\t\t\t\tcaption: Commandes\n"
                                                "\t\t\t\tmeasure 'Old Name'\n\t\t\t\t\tcaption: Ancien\n")
        _, findings = model_findings(variant(MODEL, {"cultures/fr-FR.tmdl": text}))
        f = only(findings, "culture-unknown-object")
        self.assertEqual(f["severity"], "error")
        self.assertEqual(f["items"], ["measure Orders[Old Name]", "table Orders"])

    def test_wrong_kind_gets_a_hint(self):
        text = MODEL["cultures/fr-FR.tmdl"].replace("measure 'Total Sales'", "column 'Total Sales'")
        _, findings = model_findings(variant(MODEL, {"cultures/fr-FR.tmdl": text}))
        self.assertEqual(only(findings, "culture-unknown-object")["items"],
                         ["column Sales[Total Sales] (the model has a measure by that name)"])

    def test_an_object_captioned_twice_is_an_error(self):
        text = MODEL["cultures/fr-FR.tmdl"] + "\t\t\ttable Region\n\t\t\t\tcaption: Région\n"
        _, findings = model_findings(variant(MODEL, {"cultures/fr-FR.tmdl": text}))
        self.assertEqual(only(findings, "culture-duplicate")["items"], ["table Region"])

    def test_space_indentation_warns_but_still_parses(self):
        spaced = MODEL["cultures/fr-FR.tmdl"].replace("\t", "  ")
        model, findings = model_findings(variant(MODEL, {"cultures/fr-FR.tmdl": spaced}))
        self.assertEqual(only(findings, "culture-indentation")["severity"], "warning")
        self.assertEqual(ct.model_coverage(model)["fr-FR"]["translated"], 4)

    def test_file_name_and_declared_culture_must_agree(self):
        files = variant(MODEL, {"cultures/fr-CA.tmdl": MODEL["cultures/fr-FR.tmdl"]})
        model, findings = model_findings(files)
        self.assertEqual(only(findings, "culture-name")["file"], "cultures/fr-CA.tmdl")
        self.assertEqual(only(findings, "culture-duplicate")["severity"], "error")
        _, findings = model_findings(variant(MODEL, {"cultures/xx.tmdl": "translations\n"}))
        self.assertEqual(only(findings, "culture-unreadable")["severity"], "error")

    def test_base_culture_captions_that_rename_objects_are_reported(self):
        base = tabs("""
cultureInfo en-US

    translations

        model Model

            table Sales
                caption: Sales

                measure 'Total Sales'
                    caption: Revenue
""")
        _, findings = model_findings(variant(MODEL, {"cultures/en-US.tmdl": base}))
        f = only(findings, "culture-base-captions")
        self.assertEqual((f["severity"], f["items"]), ("info", ["measure Sales[Total Sales]"]))

    def test_quoted_names_and_quoted_captions(self):
        table = MODEL["tables/Sales.tmdl"] + "\n\tmeasure 'Owner''s Total' = 1\n"
        culture = MODEL["cultures/fr-FR.tmdl"].replace(
            "\t\t\t\tcolumn Region\n", "\t\t\t\tmeasure 'Owner''s Total'\n\t\t\t\t\tcaption: \" Total \"\"net\"\" \"\n"
            "\t\t\t\tcolumn Region\n")
        model = ct.analyze_model(variant(MODEL, {"tables/Sales.tmdl": table, "cultures/fr-FR.tmdl": culture}))
        key = ("measure", "sales", "", "owner's total")
        self.assertIn(key, model.objects)
        self.assertEqual(model.cultures["fr-fr"]["captions"][key], ' Total "net" ')


class ResourceTests(unittest.TestCase):
    def test_good_resources_have_no_findings(self):
        sets, coverage, findings = resx_findings(STRINGS)
        self.assertEqual(findings, [])
        self.assertIn("Profit & Loss", sets["strings"]["files"]["en-us"]["entries"])
        self.assertEqual(coverage["Strings"]["cultures"]["de-DE"]["translated"], 3)

    def test_non_string_resources_are_ignored(self):
        text = STRINGS["Strings.en-US.resx"].replace(
            "</root>", '  <data name="Logo" type="System.Resources.ResXFileRef, System.Windows.Forms">\n'
            "    <value>logo.png</value>\n  </data>\n</root>")
        _, _, findings = resx_findings(variant(STRINGS, {"Strings.en-US.resx": text}))
        self.assertEqual(findings, [])

    def test_missing_extra_empty_and_duplicate_keys(self):
        fr = resx(("Total Sales", "Ventes totales"), ("Sales by region", " "), ("Old title", "Ancien titre"),
                  ("Old title", "Ancien titre"))
        _, coverage, findings = resx_findings(variant(STRINGS, {"Strings.fr-FR.resx": fr}))
        self.assertEqual(only(findings, "resx-missing")["items"], ["Profit & Loss"])
        self.assertEqual(only(findings, "resx-empty")["items"], ["Sales by region"])
        self.assertEqual(only(findings, "resx-extra")["severity"], "warning")
        self.assertEqual(only(findings, "resx-duplicate")["items"], ["Old title"])
        self.assertEqual(coverage["Strings"]["cultures"]["fr-FR"]["translated"], 1)

    def test_allow_pending_only_spares_keys_missing_from_every_culture(self):
        base = resx(("Total Sales", "Total Sales"), ("Sales by region", "Sales by region"),
                    ("Profit & Loss", "Profit & Loss"), ("New title", "New title"))
        de = resx(("Total Sales", "Gesamtumsatz"), ("Sales by region", "Umsatz nach Gebiet"))
        files = variant(STRINGS, {"Strings.en-US.resx": base, "Strings.de-DE.resx": de})
        _, _, findings = resx_findings(files)
        self.assertEqual({f["file"]: f["items"] for f in findings if f["check"] == "resx-missing"},
                         {"Strings.de-DE.resx": ["Profit & Loss", "New title"], "Strings.fr-FR.resx": ["New title"]})
        _, coverage, findings = resx_findings(files, allow_pending=True)
        self.assertEqual(only(findings, "resx-pending")["items"], ["New title"])
        self.assertEqual(only(findings, "resx-missing")["items"], ["Profit & Loss"])
        self.assertEqual(coverage["Strings"]["pending"], ["New title"])

    def test_untranslated_text_warns_except_same_language_and_symbols(self):
        base = resx(("Total Sales", "Total Sales"), ("Percent", "%"), ("Region", "Region"))
        de = resx(("Total Sales", "Gesamtumsatz"), ("Percent", "%"), ("Region", "Region"))
        fr = resx(("Total Sales", "Ventes totales"), ("Percent", "%"), ("Region", "Region"))
        gb = resx(("Total Sales", "Total Sales"), ("Percent", "%"), ("Region", "Region"))
        files = {"Strings.en-US.resx": base, "Strings.de-DE.resx": de, "Strings.fr-FR.resx": fr,
                 "Strings.en-GB.resx": gb}
        _, coverage, findings = resx_findings(files)
        f = only(findings, "resx-untranslated")
        self.assertEqual((f["severity"], f["items"]), ("warning", ["Region"]))
        self.assertEqual(coverage["Strings"]["cultures"]["de-DE"]["identical"], 1)

    def test_base_comes_from_the_neutral_file_when_no_culture_file_matches(self):
        files = {"Strings.resx": STRINGS["Strings.en-US.resx"], "Strings.de-DE.resx": STRINGS["Strings.de-DE.resx"]}
        _, coverage, findings = resx_findings(files, base=None)
        self.assertEqual(findings, [])
        self.assertEqual(coverage["Strings"]["baseFile"], "Strings.resx")
        _, _, findings = resx_findings({"Strings.de-DE.resx": STRINGS["Strings.de-DE.resx"]})
        self.assertEqual(only(findings, "resx-base-missing")["severity"], "error")
        _, _, findings = resx_findings({"Strings.de-DE.resx": STRINGS["Strings.de-DE.resx"]}, base=None)
        self.assertIn("--base", only(findings, "resx-base-missing")["message"])

    def test_a_neutral_file_beside_the_base_must_keep_every_key(self):
        files = variant(STRINGS, {"Strings.resx": resx(("Total Sales", "Total Sales"))})
        _, _, findings = resx_findings(files)
        self.assertEqual(only(findings, "resx-missing")["file"], "Strings.resx")

    def test_unreadable_resource_file_is_an_error(self):
        _, _, findings = resx_findings(variant(STRINGS, {"Strings.fr-FR.resx": "<root><data name='x'>"}))
        self.assertEqual(only(findings, "resx-unreadable")["severity"], "error")


class CrossChecksTests(unittest.TestCase):
    def test_names_are_keys_finds_missing_and_stale_captions(self):
        model = ct.analyze_model(MODEL)
        strings = variant(STRINGS, {"Strings.de-DE.resx": resx(
            ("Total Sales", "Umsatz gesamt"), ("Sales by region", "Umsatz nach Gebiet"),
            ("Profit & Loss", "Gewinn und Verlust"), ("Order Count", "Anzahl Bestellungen"))})
        strings["Strings.en-US.resx"] = resx(("Total Sales", "Total Sales"), ("Sales by region", "Sales by region"),
                                             ("Profit & Loss", "Profit & Loss"), ("Order Count", "Order Count"))
        strings["Strings.fr-FR.resx"] = resx(("Total Sales", "Ventes totales"), ("Order Count", "Nombre de commandes"),
                                             ("Sales by region", "Ventes par zone"), ("Profit & Loss", "P et P"))
        strings["Strings.ja-JP.resx"] = resx(("Total Sales", "総売上"))
        sets, _ = ct.analyze_resx(strings)
        findings = []
        ct.check_names_are_keys(model, sets, "en-US", findings)
        stale = only(findings, "caption-stale")
        self.assertEqual(stale["file"], "cultures/de-DE.tmdl")
        self.assertIn("measure Sales[Total Sales]", stale["items"][0])
        missing = [f for f in findings if f["check"] == "caption-missing"]
        self.assertEqual({f["file"] for f in missing}, {"cultures/fr-FR.tmdl", "cultures/ja-JP.tmdl"})
        fr = [f for f in missing if f["file"] == "cultures/fr-FR.tmdl"][0]
        self.assertEqual(fr["items"], ["measure Sales[Order Count]"])

    def test_text_table_needs_an_active_relationship(self):
        findings = []
        ct.check_text_table(ct.analyze_model(MODEL), "Report Text", findings)
        self.assertEqual(findings, [])
        relationships = MODEL["relationships.tmdl"].split("relationship 0002")[0].replace(
            "\ttoColumn: Language.Code\n", "\ttoColumn: Language.Code\n\tisActive: false\n")
        findings = []
        ct.check_text_table(ct.analyze_model(variant(MODEL, {"relationships.tmdl": relationships})), "report text",
                            findings)
        self.assertIn("inactive", only(findings, "text-table")["message"])
        findings = []
        ct.check_text_table(ct.analyze_model(variant(MODEL, remove=["relationships.tmdl"])), "Report Text", findings)
        self.assertIn("no relationship", only(findings, "text-table")["message"])
        findings = []
        ct.check_text_table(ct.analyze_model(MODEL), "Labels", findings)
        self.assertIn("no table", only(findings, "text-table")["message"])

    def test_baseline_model_finds_lost_cultures_captions_and_text_fields(self):
        old = ct.analyze_model(MODEL)
        culture = MODEL["cultures/de-DE.tmdl"].replace("\t\t\t\tcolumn Region\n\t\t\t\t\tcaption: Region\n", "")
        text_table = MODEL["tables/Report Text.tmdl"].split("\tcolumn 'Sales by region'")[0]
        new = ct.analyze_model(variant(MODEL, {"cultures/de-DE.tmdl": culture, "tables/Report Text.tmdl": text_table},
                                       remove=["cultures/fr-FR.tmdl"]))
        findings = []
        ct.check_baseline_model(new, old, "Report Text", findings)
        self.assertIn("fr-FR", only(findings, "baseline-culture-lost")["message"])
        self.assertEqual(only(findings, "baseline-caption-lost")["items"], ["column Sales[Region]"])
        self.assertEqual(only(findings, "baseline-text-lost")["items"], ["column Report Text[Sales by region]"])
        findings = []
        ct.check_baseline_model(old, old, "Report Text", findings)
        self.assertEqual(findings, [])

    def test_baseline_resources_find_lost_files_and_removed_keys(self):
        old_sets, _ = ct.analyze_resx(STRINGS)
        new = variant(STRINGS, {"Strings.en-US.resx": resx(("Total Sales", "Total Sales"),
                                                           ("Profit & Loss", "Profit & Loss"))},
                      remove=["Strings.fr-FR.resx"])
        sets, _ = ct.analyze_resx(new)
        findings = []
        ct.check_baseline_resx(sets, old_sets, "en-US", findings)
        self.assertEqual(only(findings, "baseline-resx-lost")["items"], ["Strings.fr-FR.resx"])
        self.assertEqual(only(findings, "baseline-key-removed")["items"], ["Sales by region"])


class CommandLineTests(unittest.TestCase):
    def write(self, files):
        root = os.path.join(HERE, "_scratch_%d_%s" % (os.getpid(), self._testMethodName))
        self.addCleanup(shutil.rmtree, root, True)
        for rel, text in files.items():
            path = os.path.join(root, *rel.split("/"))
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(text)
        return root

    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = ct.main(argv)
        return code, out.getvalue()

    def test_exit_codes_text_and_json(self):
        files = {"Sample.SemanticModel/definition/" + k: v for k, v in MODEL.items()}
        files.update({"Resources/" + k: v for k, v in STRINGS.items()})
        root = self.write(files)
        model, resources = os.path.join(root, "Sample.SemanticModel"), os.path.join(root, "Resources")
        code, text = self.run_main(["--model", model, "--resx", resources, "--text-table", "Report Text",
                                    "--names-are-keys"])
        self.assertEqual(code, 0, text)
        self.assertIn("fr-FR", text)
        self.assertIn("4/11", text)
        with open(os.path.join(resources, "Strings.fr-FR.resx"), "w", encoding="utf-8") as fh:
            fh.write(resx(("Total Sales", "Ventes totales")))
        code, text = self.run_main(["--model", model, "--resx", resources, "--json"])
        self.assertEqual(code, 1)
        report = json.loads(text)
        self.assertEqual(report["counts"]["error"], 1)
        self.assertEqual(report["findings"][0]["check"], "resx-missing")
        self.assertEqual(report["model"]["cultures"]["de-DE"]["translated"], 11)
        code, text = self.run_main(["--model", os.path.join(root, "nowhere")])
        self.assertEqual(code, 1)
        self.assertIn("model-unreadable", text)

    def test_argument_errors_exit_with_2(self):
        for argv in ([], ["--resx", "x", "--names-are-keys"], ["--resx", "x", "--text-table", "T"],
                     ["--model", "x", "--baseline-resx", "y"]):
            with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as raised:
                ct.main(argv)
            self.assertEqual(raised.exception.code, 2, argv)


if __name__ == "__main__":
    unittest.main()
