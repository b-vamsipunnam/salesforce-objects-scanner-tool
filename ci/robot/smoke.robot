*** Settings ***
Documentation     CI-safe tests of the production Robot Framework keywords.
Library           Collections
Library           OperatingSystem
Resource          ../../src/robot/resources/keywords.robot
Suite Teardown    Cleanup Smoke Artifacts


*** Test Cases ***
Smoke - Resource Loads
    Should Be Equal    ${SF_CLI}    sf

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
    ${reason}=    Get Skip Reason    ${error_json}
    Should Be Equal    ${reason}    REQUIRES_WHERE_StatType

Smoke - Missing Alias Has Actionable Validation
    ${status}    ${message}=    Run Keyword And Ignore Error    Validate Org Alias
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    ORG_ALIAS is required

Smoke - Process Output Is Never Shared Through PIPE
    ${salesforce_resource}=    Get File    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}salesforce.resource
    ${parallel_resource}=    Get File
    ...    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}parallel_execution.resource
    ${reporting_resource}=    Get File    ${CURDIR}${/}..${/}..${/}src${/}robot${/}resources${/}reporting.resource
    Should Not Contain    ${salesforce_resource}    stdout=PIPE
    Should Not Contain    ${salesforce_resource}    stderr=PIPE
    Should Not Contain    ${parallel_resource}    stdout=PIPE
    Should Not Contain    ${parallel_resource}    stderr=PIPE
    Should Not Contain    ${reporting_resource}    stdout=PIPE
    Should Not Contain    ${reporting_resource}    stderr=PIPE

Smoke - Operational Failure Fails Quality Gate
    &{skipped}=    Create Dictionary    Account=INVALID_JSON_OUTPUT
    ${status}    ${message}=    Run Keyword And Ignore Error    Validate Scan Quality    ${skipped}
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    operational failures

Smoke - Unknown Error Becomes Operational Failure
    ${error_json}=    Set Variable    {"name":"NEW_SALESFORCE_ERROR","message":"unexpected"}
    ${reason}=    Get Skip Reason    ${error_json}
    Should Be Equal    ${reason}    OTHER_ERROR
    &{skipped}=    Create Dictionary    Account=${reason}
    ${status}    ${message}=    Run Keyword And Ignore Error    Validate Scan Quality    ${skipped}
    Should Be Equal    ${status}    FAIL
    Should Contain    ${message}    OTHER_ERROR

Smoke - Expected Skip Passes Quality Gate
    &{skipped}=    Create Dictionary    AggregateResult=INVALID_TYPE
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

Smoke - Invalid Successful Artifact Is Rejected
    ${artifact_directory}=    Set Variable    ${OUTPUT DIR}${/}schema-artifacts
    Create Directory    ${artifact_directory}
    ${artifact}=    Set Variable    ${artifact_directory}${/}data__Account.json
    Create File
    ...    ${artifact}
    ...    {"object_name":"Account","tooling":false,"count":null,"reason":"OK","duration":1}
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
Cleanup Smoke Artifacts
    [Documentation]    Remove only schema-test artifacts inside this Robot output directory.
    Run Keyword And Ignore Error    Remove Directory    ${OUTPUT DIR}${/}schema-artifacts    recursive=${TRUE}
    Run Keyword And Ignore Error    Remove Directory    ${OUTPUT DIR}${/}missing-artifacts    recursive=${TRUE}
