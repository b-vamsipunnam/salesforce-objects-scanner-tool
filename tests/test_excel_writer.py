import json
import subprocess
import sys
import tempfile
import unittest
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
                self.assertTrue(sheet.auto_filter.ref)
                self.assertTrue(sheet.tables)
            self.assertEqual(workbook["Data Objects"]["B2"].value, 100)

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
