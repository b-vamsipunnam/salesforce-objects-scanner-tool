import unittest
from unittest.mock import patch

from src.robot.libraries.SfUtils import parse_sf_json, resolve_executable


class SfUtilsTests(unittest.TestCase):
    def test_parses_json_between_noisy_prefix_and_suffix(self):
        raw = 'warning {not json}\n{"status": 0, "result": ["Account"]}\ntrailing'
        self.assertEqual(parse_sf_json(raw)["result"], ["Account"])

    def test_parses_top_level_array(self):
        self.assertEqual(parse_sf_json("warning\n[1, 2]\ntrailing"), [1, 2])

    def test_prefers_salesforce_payload_over_json_in_warning(self):
        raw = '{"warning": "plugin notice"}\n{"status": 0, "result": ["Account"]}'
        self.assertEqual(parse_sf_json(raw)["result"], ["Account"])

    def test_prefers_payload_over_warning_with_name(self):
        raw = '{"name": "plugin-warning"}\n{"status": 0, "result": ["Account"]}'
        self.assertEqual(parse_sf_json(raw)["result"], ["Account"])

    def test_parses_structured_salesforce_error(self):
        raw = 'warning\n{"name": "INVALID_TYPE", "message": "unsupported"}'
        self.assertEqual(parse_sf_json(raw)["name"], "INVALID_TYPE")

    def test_rejects_output_without_json(self):
        with self.assertRaises(ValueError):
            parse_sf_json("warning only")

    @patch("src.robot.libraries.SfUtils.shutil.which", return_value=None)
    def test_missing_executable_has_clear_error(self, _):
        with self.assertRaisesRegex(AssertionError, "sf was not found"):
            resolve_executable("sf")


if __name__ == "__main__":
    unittest.main()
