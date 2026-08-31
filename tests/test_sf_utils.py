import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from src.robot.libraries.SfUtils import (
    classify_sf_error,
    get_sf_error_details,
    is_sf_failure_retryable,
    is_verified_deterministic_sf_failure,
    parse_sf_json,
    resolve_executable,
    run_sf_command_safely,
    sanitize_sf_text,
)


class SfUtilsTests(unittest.TestCase):
    def test_parses_json_between_noisy_prefix_and_suffix(self):
        raw = 'warning {not json}\n{"status": 0, "result": ["Account"]}\ntrailing'
        self.assertEqual(parse_sf_json(raw)["result"], ["Account"])

    def test_parses_top_level_array(self):
        self.assertEqual(parse_sf_json("warning\n[1, 2]\ntrailing"), [1, 2])

    def test_prefers_complete_noisy_tooling_response_over_nested_list(self):
        raw = 'warning\n{"sobjects":[{"name":"Account","queryable":true}]}'
        self.assertEqual(parse_sf_json(raw)["sobjects"][0]["name"], "Account")

    def test_safe_runner_redacts_credentials_before_returning_data(self):
        secret = "fakeIntegrationAccessToken123"
        script = (
            "import json; print(json.dumps({"
            f"'accessToken':'{secret}', 'message':'Bearer {secret}', 'result':[]"
            "}))"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = run_sf_command_safely(
                sys.executable, ["-c", script], directory, 5
            )
            self.assertTrue(result["ok"])
            self.assertNotIn(secret, json.dumps(result))
            self.assertEqual(result["data"]["accessToken"], "[REDACTED_CREDENTIAL]")
            self.assertEqual(list(Path(directory).glob(".sf-*")), [])

    def test_safe_runner_handles_large_file_backed_output(self):
        script = (
            "import json; print('warning ' + 'x' * 2_000_000); "
            "print(json.dumps({'status':0,'result':{'totalSize':7}}))"
        )
        with tempfile.TemporaryDirectory() as directory:
            result = run_sf_command_safely(
                sys.executable, ["-c", script], directory, 10
            )
            self.assertTrue(result["ok"])
            self.assertEqual(result["data"]["result"]["totalSize"], 7)

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

    def test_classifies_only_matching_query_limitation(self):
        raw = (
            '{"name":"INVALID_TYPE_FOR_OPERATION",'
            '"message":"entity type AccountChangeEvent does not support query"}'
        )
        self.assertEqual(
            classify_sf_error(raw, "AccountChangeEvent"),
            "QUERY_NOT_SUPPORTED",
        )
        self.assertEqual(
            classify_sf_error(raw, "Account"),
            "INVALID_TYPE_FOR_OPERATION",
        )

    def test_same_object_with_wrong_message_remains_operational(self):
        raw = (
            '{"name":"INVALID_TYPE_FOR_OPERATION",'
            '"message":"AccountChangeEvent failed for an unrelated reason"}'
        )
        self.assertEqual(
            classify_sf_error(raw, "AccountChangeEvent"),
            "INVALID_TYPE_FOR_OPERATION",
        )

    def test_verified_run_restrictions_require_exact_rule_match(self):
        cases = (
            (
                "ContentDocumentLink",
                False,
                "MALFORMED_QUERY",
                "Implementation restriction: ContentDocumentLink requires a filter by Id.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "ContentFolderItem",
                False,
                "MALFORMED_QUERY",
                "Implementation restriction: ContentFolderItem requires a filter by Id.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "ContentFolderMember",
                False,
                "MALFORMED_QUERY",
                "Implementation restriction: ContentFolderMember requires a filter by Id.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "ContentVersionRenditionContent",
                False,
                "MALFORMED_QUERY",
                "ContentVersionId must be specified in your query.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "IdeaComment",
                False,
                "MALFORMED_QUERY",
                "Implementation restriction. When querying the Idea Comment object, you must filter by IdeaId.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "Vote",
                False,
                "MALFORMED_QUERY",
                "Implementation restriction: When querying the Vote object, you must filter by ParentId.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "SubscriberPackage",
                True,
                "MALFORMED_QUERY",
                "Implementation restriction: You can only perform queries of the form Id='<some_value>'.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "DataStatistics",
                False,
                "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
                "Where clauses should contain StatType",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "DatacloudDandBCompany",
                False,
                "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
                "Datacloud D&B company is not filterable without a criteria.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "FlexQueueItem",
                False,
                "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
                "The WHERE clause must contain a JobType field expression.",
                "RESTRICTIVE_FILTER_REQUIRED",
            ),
            (
                "EventBusSubscriber",
                False,
                "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
                "COUNT() query could not be processed",
                "QUERY_NOT_SUPPORTED",
            ),
            (
                "PendingOrderSummary",
                False,
                "EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION",
                "COUNT() query could not be processed",
                "QUERY_NOT_SUPPORTED",
            ),
            (
                "DatacloudAddress",
                False,
                "EXTERNAL_OBJECT_EXCEPTION",
                "SObject - DATACLOUD_ADDRESS : Transient queries are not implemented",
                "QUERY_NOT_SUPPORTED",
            ),
        )
        for object_name, tooling, error_name, message, expected in cases:
            raw = json.dumps({"name": error_name, "message": message})
            with self.subTest(object_name=object_name, tooling=tooling):
                self.assertEqual(classify_sf_error(raw, object_name, tooling), expected)
                self.assertEqual(
                    classify_sf_error(raw, f"Wrong{object_name}", tooling),
                    error_name,
                )
                wrong_message = json.dumps(
                    {"name": error_name, "message": "Different operational failure"}
                )
                self.assertEqual(
                    classify_sf_error(wrong_message, object_name, tooling),
                    error_name,
                )

    def test_malformed_query_is_operational_unless_verified(self):
        generic = '{"name":"MALFORMED_QUERY","message":"unexpected syntax"}'
        verified = (
            '{"name":"MALFORMED_QUERY",'
            '"message":"FieldDefinition: a filter on a reified column is required [DurableId]"}'
        )
        self.assertEqual(classify_sf_error(generic, "Account"), "MALFORMED_QUERY")
        self.assertEqual(
            classify_sf_error(verified, "FieldDefinition"),
            "RESTRICTIVE_FILTER_REQUIRED",
        )

    def test_datacloud_skip_requires_explicit_policy(self):
        raw = (
            '{"name":"DATACLOUD_API_DISABLED_EXCEPTION",'
            '"message":"Your organization doesn\'t have permission to access the Data.com API"}'
        )
        self.assertEqual(
            classify_sf_error(raw, "DatacloudCompany", allow_disabled_datacloud=False),
            "DATACLOUD_API_DISABLED_EXCEPTION",
        )
        self.assertEqual(
            classify_sf_error(raw, "DatacloudCompany", allow_disabled_datacloud=True),
            "DATACLOUD_INTENTIONALLY_DISABLED",
        )

    def test_retries_only_external_failures_with_transient_evidence(self):
        transient = {"message": "Provider temporarily unavailable. Try again."}
        unavailable_feature = {
            "message": "Cannot access: EinsteinAgentSettings in this organization"
        }
        schema_mismatch = {
            "message": (
                'The "Id" field is of type number, but the value from the '
                'external system is "02ufj000008DMJ4AAO".'
            )
        }
        self.assertTrue(
            is_sf_failure_retryable("EXTERNAL_OBJECT_EXCEPTION", transient)
        )
        self.assertFalse(
            is_sf_failure_retryable(
                "EXTERNAL_OBJECT_EXCEPTION",
                unavailable_feature,
                "EinsteinAgentSettings",
                True,
            )
        )
        self.assertFalse(
            is_sf_failure_retryable(
                "EXTERNAL_OBJECT_EXCEPTION",
                schema_mismatch,
                "PlatformEventUsageMetric",
            )
        )
        self.assertTrue(
            is_sf_failure_retryable("REQUEST_LIMIT_EXCEEDED", {"message": "Limit"})
        )

    def test_unknown_exception_requires_transient_evidence(self):
        self.assertTrue(
            is_sf_failure_retryable(
                "UNKNOWN_EXCEPTION",
                {"message": "An unexpected error occurred. ErrorId: 123"},
            )
        )
        self.assertFalse(
            is_sf_failure_retryable(
                "UNKNOWN_EXCEPTION",
                {"message": "Deterministic provider validation failure"},
            )
        )

    def test_user_app_menu_item_schema_rule_requires_exact_context(self):
        details = {
            "message": (
                'The "Id" field is of type number, but the value from the '
                'external system is "12/17/25 12:00 AM".'
            )
        }
        self.assertTrue(
            is_verified_deterministic_sf_failure(
                "EXTERNAL_OBJECT_EXCEPTION",
                details,
                "UserAppMenuItem",
                False,
            )
        )
        self.assertFalse(
            is_verified_deterministic_sf_failure(
                "EXTERNAL_OBJECT_EXCEPTION",
                details,
                "DifferentObject",
                False,
            )
        )
        self.assertFalse(
            is_verified_deterministic_sf_failure(
                "EXTERNAL_OBJECT_EXCEPTION",
                details,
                "UserAppMenuItem",
                True,
            )
        )

    def test_deterministic_retry_rules_reject_similar_messages(self):
        exact = {"message": "Unable to invoke method: getField"}
        similar_method = {"message": "Unable to invoke methods: getField"}
        similar_schema = {
            "message": (
                'The "Id" field is of numeric type, but the value from the '
                'external system is "12/17/25 12:00 AM".'
            )
        }
        self.assertTrue(
            is_verified_deterministic_sf_failure(
                "EXTERNAL_OBJECT_EXCEPTION",
                exact,
                "KnowledgeWorkOrderField",
                True,
            )
        )
        self.assertFalse(
            is_verified_deterministic_sf_failure(
                "EXTERNAL_OBJECT_EXCEPTION",
                similar_method,
                "KnowledgeWorkOrderField",
                True,
            )
        )
        self.assertFalse(
            is_verified_deterministic_sf_failure(
                "EXTERNAL_OBJECT_EXCEPTION",
                similar_schema,
                "UserAppMenuItem",
                False,
            )
        )

    def test_sanitizes_structured_and_unstructured_errors(self):
        structured = get_sf_error_details(
            '{"name":"UNKNOWN_EXCEPTION","message":"ErrorId 123","stack":"secret"}'
        )
        self.assertEqual(
            structured, {"name": "UNKNOWN_EXCEPTION", "message": "ErrorId 123"}
        )
        unstructured = get_sf_error_details("Bearer abc123 access_token=xyz")
        self.assertNotIn("abc123", unstructured["message"])
        self.assertNotIn("xyz", unstructured["message"])

    def test_redacts_encoded_mixed_case_and_salesforce_credentials(self):
        raw = (
            "AuThOrIzAtIoN: bEaReR mixedCaseSecret "
            "authorization%3A%20bearer%20encodedSecret "
            "force://client:secret:refresh@example.my.salesforce.com "
            "force%3A%2F%2Fclient%3Asecret%3Arefresh%40example "
            "sessionId=00Dxx0000000001!longSessionSecret "
            "access_token%3DencodedAccessSecret"
        )
        sanitized = sanitize_sf_text(raw)
        for secret in (
            "mixedCaseSecret",
            "encodedSecret",
            "client:secret:refresh",
            "longSessionSecret",
            "encodedAccessSecret",
        ):
            self.assertNotIn(secret, sanitized)
        self.assertIn("[REDACTED_BEARER_TOKEN]", sanitized)
        self.assertIn("[REDACTED_AUTH_URL]", sanitized)
        self.assertIn("[REDACTED_SESSION_ID]", sanitized)
        self.assertIn("[REDACTED_ACCESS_TOKEN]", sanitized)

    def test_caps_all_retained_message_text(self):
        details = get_sf_error_details(
            json.dumps({"name": "ERROR", "message": "x" * 10_000})
        )
        self.assertLessEqual(len(details["message"]), 4000)
        self.assertTrue(details["message"].endswith("...[TRUNCATED]"))

    @patch("src.robot.libraries.SfUtils.shutil.which", return_value=None)
    def test_missing_executable_has_clear_error(self, _):
        with self.assertRaisesRegex(AssertionError, "sf was not found"):
            resolve_executable("sf")


if __name__ == "__main__":
    unittest.main()
