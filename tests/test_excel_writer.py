import json
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
import zipfile
from pathlib import Path

from openpyxl import load_workbook


class ExcelWriterTests(unittest.TestCase):
    def test_generates_formatted_workbook(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = [
                {"Account": 100},
                {"ApexClass": 4},
                {"AggregateResult": "INVALID_TYPE"},
                {"Account": 0.25},
            ]
            paths = []
            for index, payload in enumerate(inputs):
                path = root / f"{index}.json"
                path.write_text(json.dumps(payload), encoding="utf-8")
                paths.append(path)
            output = root / "report.xlsx"
            script = Path("src/robot/libraries/ExcelWriter.py")
            result = subprocess.run(
                [sys.executable, str(script), *(str(path) for path in paths), str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            workbook = load_workbook(output)
            self.assertEqual(
                workbook.sheetnames,
                ["Data Objects", "Tooling Objects", "Skipped Objects", "Durations (Seconds)"],
            )
            for sheet in workbook.worksheets:
                self.assertEqual(sheet.freeze_panes, "A2")
                self.assertIsNone(sheet.auto_filter.ref)
                self.assertTrue(sheet.tables)
            self.assertEqual(workbook["Data Objects"]["B2"].value, 100)

            namespace = {"x": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
            with zipfile.ZipFile(output) as archive:
                worksheet_names = [
                    name
                    for name in archive.namelist()
                    if name.startswith("xl/worksheets/sheet") and name.endswith(".xml")
                ]
                table_names = [
                    name for name in archive.namelist() if name.startswith("xl/tables/table")
                ]
                self.assertEqual(len(worksheet_names), 4)
                self.assertEqual(len(table_names), 4)
                for name in worksheet_names:
                    worksheet = ET.fromstring(archive.read(name))
                    self.assertIsNone(worksheet.find("x:autoFilter", namespace))
                for name in table_names:
                    table = ET.fromstring(archive.read(name))
                    self.assertIsNotNone(table.find("x:autoFilter", namespace))

    def test_rejects_non_dictionary_input(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            inputs = [[], {}, {}, {}]
            paths = []
            for index, payload in enumerate(inputs):
                path = root / f"{index}.json"
                path.write_text(json.dumps(payload), encoding="utf-8")
                paths.append(path)
            output = root / "report.xlsx"
            script = Path("src/robot/libraries/ExcelWriter.py")
            result = subprocess.run(
                [sys.executable, str(script), *(str(path) for path in paths), str(output)],
                capture_output=True,
                text=True,
                check=False,
            )
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
