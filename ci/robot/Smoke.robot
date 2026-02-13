*** Settings ***
Documentation     Smoke tests for salesforce-objects-scanner
...               Fast CI-safe checks (no real Salesforce connection)

Library           OperatingSystem
Library           Collections
Library           BuiltIn
Library           Process
Resource          ../../src/robot/tests/Support.robot


*** Keywords ***
Is Windows
    ${os}=    Evaluate    __import__("os").name
    RETURN    ${os} == "nt"


Build Sf Command
    [Documentation]    Builds cross-platform sf command list
    [Arguments]    @{sf_args}

    ${is_win}=    Is Windows

    IF    ${is_win}
        @{base}=    Create List    cmd.exe    /c    ${SF_CLI}
    ELSE
        @{base}=    Create List    ${SF_CLI}
    END

    @{cmd}=    Combine Lists    ${base}    @{sf_args}
    RETURN    @{cmd}


*** Test Cases ***

Smoke - Resource Loads
    [Documentation]    Ensures Support.robot imports correctly
    Should Not Be Empty    ${SF_CLI}
    Should Be Equal        ${SF_CLI}    sf
    Log    Support.robot loaded successfully


Smoke - Build Sf Command Cross Platform
    [Documentation]    Validates command construction logic
    @{cmd}=    Build Sf Command    --version

    ${is_win}=    Is Windows
    IF    ${is_win}
        Should Be Equal    ${cmd}[0]    cmd.exe
        Should Be Equal    ${cmd}[1]    /c
        Should Be Equal    ${cmd}[2]    sf
    ELSE
        Should Be Equal    ${cmd}[0]    sf
    END


Smoke - Safe Parse Sf Json With Warning Prefix
    [Documentation]    Ensures CLI warning lines are ignored during parsing
    ${fake_output}=    Catenate    SEPARATOR=\n
    ...    Warning: @salesforce/cli update available.
    ...    {
    ...      "status": 0,
    ...      "result": ["Account", "Contact"]
    ...    }

    ${parsed}=    Safe Parse Sf Json    ${fake_output}

    Should Be Equal As Integers    ${parsed}[status]    0
    Length Should Be               ${parsed}[result]    2
    List Should Contain Value      ${parsed}[result]    Account


Smoke - Get Skip Reason - JSON Error
    ${error_json}=    {"name": "INVALID_TYPE_FOR_OPERATION", "message": "Count not supported"}
    ${reason}=        Get Skip Reason    ${error_json}
    Should Be Equal   ${reason}    COUNT_NOT_SUPPORTED


Smoke - Filter Countable Objects
    @{objects}=    Create List
    ...    Account
    ...    AccountHistory
    ...    AccountFeed
    ...    CustomObject__c
    ...    DataEncryptionKey
    ...    ApexClass

    @{filtered}=    Filter Countable Objects    @{objects}

    List Should Not Contain Value    ${filtered}    AccountHistory
    List Should Not Contain Value    ${filtered}    AccountFeed
    List Should Not Contain Value    ${filtered}    DataEncryptionKey
    List Should Contain Value        ${filtered}    Account
    List Should Contain Value        ${filtered}    CustomObject__c


Smoke - JSON Structure Generation
    @{mock_objects}=    Create List    Account    Contact
    @{filtered}=        Filter Countable Objects    @{mock_objects}
    Should Not Be Empty    ${filtered}

    &{mock_results}=      Create Dictionary    Account=100    Contact=50
    &{mock_durations}=    Create Dictionary    Account=1.2    Contact=0.8

    ${generated_at}=      Evaluate    __import__("datetime").datetime.utcnow().isoformat()

    &{payload}=    Create Dictionary
    ...    org_alias=TestOrg
    ...    generated_at=${generated_at}
    ...    data_objects=${mock_results}
    ...    durations_seconds=${mock_durations}

    ${json}=    Evaluate    __import__("json").dumps($payload)

    Should Contain    ${json}    "Account"
    Should Contain    ${json}    "generated_at"


Smoke - Critical Keywords Callable
    Run Keyword    Build Sf Command    --version
    Run Keyword    Safe Parse Sf Json    {"status":0}
    Run Keyword    Get Skip Reason    INVALID_TYPE_FOR_OPERATION
    Run Keyword    Filter Countable Objects    Account    Contact
