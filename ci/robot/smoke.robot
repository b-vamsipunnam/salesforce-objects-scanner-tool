*** Settings ***
Documentation     CI-safe tests of the production Robot Framework keywords.
Library           Collections
Library           OperatingSystem
Resource          ../../src/robot/resources/keywords.robot
Suite Teardown    Cleanup Smoke Artifacts


*** Test Cases ***
Smoke - Resource Loads
    Should Be Equal    ${SF_CLI}    sf
    Should Be Equal    ${VERBOSE_OBJECT_RESULTS}    ${FALSE}

Smoke - Safe Parse Sf Json With Noisy Output
    ${fake_output}=    Catenate    SEPARATOR=\n
    ...    Warning {not-json}: update available
    ...    {"status": 0, "result": ["Account", "Contact"]}
    ...    trailing diagnostic
    ${parsed}=    Safe Parse Sf Json    ${fake_output}
    Should Be Equal As Integers    ${parsed}[status]    0
    Length Should Be               ${parsed}[result]    2

Smoke - Get Skip Reason From JSON Error
    ${error_json}=    Set Variable    {"name":"INVALID_TYPE_FOR_OPERATION","message":"Count operation not supported"}
    ${reason}=        Get Skip Reason    ${error_json}
    Should Be Equal   ${reason}    COUNT_NOT_SUPPORTED

Smoke - Known Salesforce Count Limitations Are Expected Skips
    ${unknown}=    Set Variable
    ...    {"name":"UNKNOWN_EXCEPTION","message":"An unexpected error occurred. Please include this ErrorId: 123"}
    ${activity_reason}=    Get Skip Reason    ${unknown}    ActivityFieldHistory    ${FALSE}
    ${tooling_reason}=    Get Skip Reason    ${unknown}    InstalledSubscriberPackage    ${TRUE}
    ${user_access}=    Set Variable
    ...    {"name":"INVALID_FIELD","message":"RecordId field must be selected"}
    ${user_access_reason}=    Get Skip Reason    ${user_access}    UserRecordAccess    ${FALSE}
    Should Be Equal    ${activity_reason}    COUNT_NOT_SUPPORTED
    Should Be Equal    ${tooling_reason}    COUNT_NOT_SUPPORTED
    Should Be Equal    ${user_access_reason}    RESTRICTIVE_FILTER_REQUIRED

Smoke - Unknown Exceptions Remain Operational For Other Objects
    ${unknown}=    Set Variable
    ...    {"name":"UNKNOWN_EXCEPTION","message":"An unexpected error occurred. Please include this ErrorId: 123"}
    ${data_reason}=    Get Skip Reason    ${unknown}    Account    ${FALSE}
    ${wrong_api_reason}=    Get Skip Reason    ${unknown}    InstalledSubscriberPackage    ${FALSE}
    Should Be Equal    ${data_reason}    UNKNOWN_EXCEPTION
    Should Be Equal    ${wrong_api_reason}    UNKNOWN_EXCEPTION

Smoke - Filter Preserves Queryable Suffixes And Deduplicates
    @{objects}=    Create List
    ...    Account
    ...    AccountHistory
    ...    AccountFeed
    ...    CustomObject__c
    ...    Account
    @{filtered}=    Filter Countable Objects    @{objects}
    List Should Contain Value        ${filtered}    AccountHistory
    List Should Contain Value        ${filtered}    AccountFeed
    List Should Contain Value        ${filtered}    Account
    Length Should Be                 ${filtered}    4

Smoke - Unsupported Object Is Classified At Runtime
    ${error_json}=    Set Variable
    ...    {"name":"INVALID_TYPE","message":"sObject type 'AggregateResult' is not supported"}
    ${reason}=    Get Skip Reason    ${error_json}
    Should Be Equal    ${reason}    INVALID_TYPE

Smoke - Required Where Is Classified At Runtime
    ${error_json}=    Set Variable
    ...    {"name":"MALFORMED_QUERY","message":"Where clauses should contain StatType"}
    ${reason}=    Get Skip Reason    ${error_json}    DataStatistics
    Should Be Equal    ${reason}    RESTRICTIVE_FILTER_REQUIRED

Smoke - Missing Alias Has Actionable Validation
    ${status}    ${message}=    Run Keyword And Ignore Error    Validate Org Alias
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    ORG_ALIAS is required

Smoke - Salesforce Process Output Is Python Owned And File Backed
    ${salesforce_resource}=    Get File    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}salesforce.resource
    ${parallel_resource}=    Get File
    ...    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}parallel_execution.resource
    ${reporting_resource}=    Get File    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}reporting.resource
    Should Not Contain    ${salesforce_resource}    stdout=PIPE
    Should Not Contain    ${salesforce_resource}    stderr=PIPE
    Should Not Contain    ${salesforce_resource}    Start Process
    Should Not Contain    ${salesforce_resource}    Run Process
    Should Not Contain    ${parallel_resource}    stdout=PIPE
    Should Not Contain    ${parallel_resource}    stderr=PIPE
    Should Not Contain    ${reporting_resource}    stdout=PIPE
    Should Not Contain    ${reporting_resource}    stderr=PIPE

Smoke - Pabot Uses Test Level Splitting
    ${parallel_resource}=    Get File
    ...    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}parallel_execution.resource
    Should Contain    ${parallel_resource}    pabot.pabot
    Should Contain    ${parallel_resource}    --testlevelsplit

Smoke - Operational Failure Fails Quality Gate
    &{skipped}=    Create Dictionary    Account=INVALID_JSON_OUTPUT
    ${status}    ${message}=    Run Keyword And Ignore Error    Validate Scan Quality    ${skipped}
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    operational failures

Smoke - Unknown Error Becomes Operational Failure
    ${error_json}=    Set Variable    {"name":"NEW_SALESFORCE_ERROR","message":"unexpected"}
    ${reason}=    Get Skip Reason    ${error_json}
    Should Be Equal    ${reason}    NEW_SALESFORCE_ERROR
    &{skipped}=    Create Dictionary    Account=${reason}
    ${status}    ${message}=    Run Keyword And Ignore Error    Validate Scan Quality    ${skipped}
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    NEW_SALESFORCE_ERROR

Smoke - Expected Skip Passes Quality Gate
    &{skipped}=    Create Dictionary    AccountChangeEvent=QUERY_NOT_SUPPORTED
    Validate Scan Quality    ${skipped}

Smoke - Best Effort Mode Allows Operational Failure
    &{skipped}=    Create Dictionary    Account=TIMEOUT
    Validate Scan Quality    ${skipped}    fail_on_errors=${FALSE}

Smoke - Command Line Values Are Normalized
    ${include}    ${fail_on_errors}    ${processes}    ${shards}=
    ...    Normalize Scanner Configuration    false    FALSE    8    3
    Should Be Equal    ${include}    ${FALSE}
    Should Be Equal    ${fail_on_errors}    ${FALSE}
    Should Be Equal As Integers    ${processes}    8
    Should Be Equal As Integers    ${shards}    3

Smoke - Quiet Console Hides Successful Object Results
    ${log_success}=    Should Log Object Result    OK    ${FALSE}
    ${log_skip}=    Should Log Object Result    INVALID_TYPE    ${FALSE}
    Should Be Equal    ${log_success}    ${FALSE}
    Should Be Equal    ${log_skip}    ${TRUE}

Smoke - Verbose Console Shows Successful Object Results
    ${log_success}=    Should Log Object Result    OK    ${TRUE}
    ${log_skip}=    Should Log Object Result    TIMEOUT    ${TRUE}
    Should Be Equal    ${log_success}    ${TRUE}
    Should Be Equal    ${log_skip}    ${TRUE}

Smoke - Verbosity Command Line Values Are Normalized
    Normalize Scanner Configuration    verbose_value=false
    Should Be Equal    ${VERBOSE_OBJECT_RESULTS}    ${FALSE}
    Normalize Scanner Configuration    verbose_value=TRUE
    Should Be Equal    ${VERBOSE_OBJECT_RESULTS}    ${TRUE}

Smoke - Worker Configuration Round Trip Preserves Types And Text
    Verify Worker Configuration Round Trip

Smoke - Invalid Successful Artifact Is Rejected
    ${artifact_directory}=    Set Variable    ${OUTPUT DIR}${/}schema-artifacts
    Create Directory    ${artifact_directory}
    ${artifact}=    Set Variable    ${artifact_directory}${/}data__Account.json
    Create File
    ...    ${artifact}
    ...    {"object_name":"Account","tooling":false,"count":null,"reason":"OK","duration":1,"details":{}}
    ${status}    ${message}=    Run Keyword And Ignore Error
    ...    Read Query Artifact
    ...    ${artifact_directory}
    ...    Account
    ...    ${FALSE}
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    integer

Smoke - Missing Artifact Is Rejected
    ${artifact_directory}=    Set Variable    ${OUTPUT DIR}${/}missing-artifacts
    Create Directory    ${artifact_directory}
    @{data_objects}=    Create List    Account
    @{tooling_objects}=    Create List
    ${status}    ${message}=    Run Keyword And Ignore Error
    ...    Load Query Artifacts
    ...    ${artifact_directory}
    ...    ${data_objects}
    ...    ${tooling_objects}
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    result count


*** Keywords ***
Verify Worker Configuration Round Trip
    [Documentation]    Exercise scalar, list, path, and Unicode values through the worker payload.
    ${sf_cli}=    Set Variable    C:${/}Program Files${/}Salesforce CLI${/}sf.cmd
    ${artifact_directory}=    Set Variable    C:${/}Run Space${/}artifacts-東京
    @{empty_list}=    Create List
    @{tooling_limitations}=    Create List    FirstToolingObject    SecondToolingObject
    VAR    ${ORG_ALIAS}    DévHub-東京    scope=TEST
    VAR    ${SF_CLI}    ${sf_cli}    scope=TEST
    VAR    ${VERBOSE_OBJECT_RESULTS}    ${TRUE}    scope=TEST
    VAR    ${MAX_QUERY_TIMEOUT_SECONDS}    ${321}    scope=TEST
    VAR    ${CONNECTEDAPP_TIMEOUT}    ${654}    scope=TEST
    VAR    ${POLL_INTERVAL_SECONDS}    ${0.25}    scope=TEST
    VAR    ${SF_TRANSIENT_RETRIES}    ${4}    scope=TEST
    VAR    ${SF_RETRY_BACKOFF_SECONDS}    ${1.5}    scope=TEST
    VAR    ${ALLOW_DISABLED_DATACLOUD}    ${TRUE}    scope=TEST
    VAR    ${SLOW_OBJECTS}    FirstObject, SecondObject    scope=TEST
    VAR    ${TRANSIENT_FAILURE_REASONS}    REQUEST_LIMIT_EXCEEDED, UNKNOWN_EXCEPTION    scope=TEST
    VAR    ${KNOWN_UNKNOWN_DATA_OBJECTS}    ${empty_list}    scope=TEST
    VAR    ${KNOWN_UNKNOWN_TOOLING_OBJECTS}    ${tooling_limitations}    scope=TEST
    ${payload}=    Build Pabot Worker Configuration    ${artifact_directory}
    VAR    ${ORG_ALIAS}    reset    scope=TEST
    VAR    ${SF_CLI}    reset    scope=TEST
    VAR    ${VERBOSE_OBJECT_RESULTS}    ${FALSE}    scope=TEST
    VAR    ${MAX_QUERY_TIMEOUT_SECONDS}    ${1}    scope=TEST
    VAR    ${CONNECTEDAPP_TIMEOUT}    ${1}    scope=TEST
    VAR    ${POLL_INTERVAL_SECONDS}    ${1}    scope=TEST
    VAR    ${SF_TRANSIENT_RETRIES}    ${0}    scope=TEST
    VAR    ${SF_RETRY_BACKOFF_SECONDS}    ${0}    scope=TEST
    VAR    ${ALLOW_DISABLED_DATACLOUD}    ${FALSE}    scope=TEST
    Apply Pabot Worker Configuration    ${payload}
    Should Be Equal    ${ORG_ALIAS}    DévHub-東京
    Should Be Equal    ${SF_CLI}    ${sf_cli}
    Should Be Equal    ${ARTIFACT_DIR}    ${artifact_directory}
    Should Be Equal    ${VERBOSE_OBJECT_RESULTS}    ${TRUE}
    Should Be Equal As Integers    ${MAX_QUERY_TIMEOUT_SECONDS}    321
    Should Be Equal As Integers    ${CONNECTEDAPP_TIMEOUT}    654
    Should Be Equal As Numbers    ${POLL_INTERVAL_SECONDS}    0.25
    Should Be Equal As Integers    ${SF_TRANSIENT_RETRIES}    4
    Should Be Equal As Numbers    ${SF_RETRY_BACKOFF_SECONDS}    1.5
    Should Be Equal    ${ALLOW_DISABLED_DATACLOUD}    ${TRUE}
    Lists Should Be Equal    ${SLOW_OBJECTS}    ${{['FirstObject', 'SecondObject']}}
    Lists Should Be Equal
    ...    ${TRANSIENT_FAILURE_REASONS}
    ...    ${{['REQUEST_LIMIT_EXCEEDED', 'UNKNOWN_EXCEPTION']}}
    Should Be Empty    ${KNOWN_UNKNOWN_DATA_OBJECTS}
    Lists Should Be Equal    ${KNOWN_UNKNOWN_TOOLING_OBJECTS}    ${tooling_limitations}

Cleanup Smoke Artifacts
    [Documentation]    Remove only schema-test artifacts inside this Robot output directory.
    Run Keyword And Ignore Error    Remove Directory    ${OUTPUT DIR}${/}schema-artifacts    recursive=${TRUE}
    Run Keyword And Ignore Error    Remove Directory    ${OUTPUT DIR}${/}missing-artifacts    recursive=${TRUE}
