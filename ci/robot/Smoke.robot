*** Settings ***
Documentation    Smoke tests for salesforce-objects-scanner
...              Fast checks that must pass in CI - no real Salesforce connection

Library          OperatingSystem
Library          Collections
Library          BuiltIn
Library          String
Library          Process
Library          DateTime
Library          json
Resource         ../../src/robot/tests/Support.robot

*** Keywords ***
Build Sf Command
    [Documentation]    Builds cross-platform sf command list (handles Windows sf.cmd)
    [Arguments]    @{sf_args}
    ${is_win}=    Is Windows
    IF    ${is_win}
        @{base}=    Create List    cmd.exe    /c    ${SF_CLI}
    ELSE
        @{base}=    Create List    ${SF_CLI}
    END
    @{cmd}=    Combine Lists    ${base}    @{sf_args}
    RETURN    @{cmd}

Is Windows
    [Documentation]    Returns ${TRUE} if running on Windows
    ${os}=    Evaluate    __import__("os").name
    RETURN    ${os} == 'nt'

*** Test Cases ***
Smoke - Syntax And Import Check
    [Documentation]    Ensures the main resource file loads without syntax errors
    Should Not Be Empty    ${SF_CLI}
    Should Be Equal    ${SF_CLI}    sf
    Log To Console    Support.robot imported successfully


Smoke - Build Sf Command (Windows simulation)
    [Documentation]    Tests cross-platform command building logic
    @{args}=    Create List    --version
    @{cmd}=    Build Sf Command    @{args}

    ${is_win}=    Is Windows
    IF    ${is_win}
        Should Contain    ${cmd}[0]    cmd.exe
        Should Contain    ${cmd}[1]    /c
        Should Contain    ${cmd}[2]    sf
    ELSE
        Should Be Equal    ${cmd}[0]    sf
    END
    Log To Console    Command built OK: @{cmd}


Smoke - Safe Parse Sf Json With Warning Prefix
    [Documentation]    Tests JSON parser cleans CLI warning messages
    ${fake_output}=    Catenate    SEPARATOR=\n
    ...    Warning: @salesforce/cli update available from 2.116.6 to 2.120.3.
    ...    {
    ...      "status": 0,
    ...      "result": ["Account", "Contact"]
    ...    }

    ${parsed}=    Safe Parse Sf Json    ${fake_output}
    Should Be Equal    ${parsed}[status]    ${0}
    Length Should Be    ${parsed}[result]    2
    Should Contain    ${parsed}[result]    Account
    Log To Console    Safe JSON parsing works with warning prefix


Smoke - Get Skip Reason - JSON Error Parsing
    [Documentation]    Tests skip reason extraction from error JSON
    ${error_json}=    Catenate    SEPARATOR=\n
    ...    {"name": "INVALID_TYPE_FOR_OPERATION", "message": "Count operation not supported"}

    ${reason}=    Get Skip Reason    ${error_json}
    Should Be Equal    ${reason}    COUNT_NOT_SUPPORTED


Smoke - Filter Countable Objects - Basic
    [Documentation]    Tests object filtering removes known noisy types
    @{test_objects}=    Create List
    ...    Account    AccountHistory    AccountFeed    CustomObject__c    DataEncryptionKey    ApexClass

    @{filtered}=    Filter Countable Objects    @{test_objects}

    List Should Not Contain Value    ${filtered}    AccountHistory
    List Should Not Contain Value    ${filtered}    AccountFeed
    List Should Not Contain Value    ${filtered}    DataEncryptionKey
    List Should Contain Value    ${filtered}    Account
    List Should Contain Value    ${filtered}    CustomObject__c
    Log To Console    Filtering logic works


Smoke - Dry Run Structure (no real CLI call)
    [Documentation]    Validates main flow structure without real execution
    # Mock minimal data
    @{mock_objects}=    Create List    Account    Contact    Opportunity
    @{filtered}=    Filter Countable Objects    @{mock_objects}
    Should Not Be Empty    ${filtered}

    &{mock_results}=    Create Dictionary    Account=100    Contact=50
    &{mock_durations}=  Create Dictionary    Account=1.2    Contact=0.8

    ${generated_at}=    Get Current Date
    &{mock_full}=    Create Dictionary
    ...    org_alias=TestOrg
    ...    generated_at=${generated_at}
    ...    data_objects=${mock_results}
    ...    durations_seconds=${mock_durations}

    ${json}=    Evaluate    json.dumps($mock_full, indent=2)    modules=json
    Should Contain    ${json}    "Account": 100
    Should Contain    ${json}    "generated_at"
    Log To Console    JSON structure generation OK


Smoke - All Critical Keywords Exist
    [Documentation]    Smoke check that main keywords are defined and callable
    Run Keyword    Build Sf Command    --version
    Run Keyword    Safe Parse Sf Json    {"status":0}
    Run Keyword    Get Skip Reason    INVALID_TYPE_FOR_OPERATION
    Run Keyword    Filter Countable Objects    Account    Contact
    Log To Console    All critical keywords are defined and callable