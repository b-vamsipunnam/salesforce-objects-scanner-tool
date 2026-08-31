import subprocess
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


FAKE_ACCESS_TOKEN = b"fakeSalesforceAccessToken_DO_NOT_LOG_12345"


class SecretContainmentTests(unittest.TestCase):
    def test_fake_token_is_absent_from_robot_json_excel_and_console(self):
        with tempfile.TemporaryDirectory() as directory:
            output_directory = Path(directory)
            completed = subprocess.run(
                [
                    sys.executable,
                    "-m",
                    "robot",
                    "--outputdir",
                    str(output_directory),
                    "--variable",
                    f"SCAN_OUTPUT_ROOT:{output_directory / 'scanner'}",
                    "ci/robot/security_smoke.robot",
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                check=False,
            )
            self.assertEqual(
                completed.returncode,
                0,
                (completed.stdout + completed.stderr).decode(errors="replace"),
            )
            self.assertNotIn(FAKE_ACCESS_TOKEN, completed.stdout + completed.stderr)
            for path in output_directory.rglob("*"):
                if not path.is_file():
                    continue
                if path.suffix == ".xlsx":
                    with zipfile.ZipFile(path) as workbook:
                        for member in workbook.namelist():
                            self.assertNotIn(FAKE_ACCESS_TOKEN, workbook.read(member))
                else:
                    self.assertNotIn(FAKE_ACCESS_TOKEN, path.read_bytes(), str(path))


if __name__ == "__main__":
    unittest.main()
