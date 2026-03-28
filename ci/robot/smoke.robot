*** Settings ***
Documentation     Smoke tests for salesforce-objects-scanner. Fast CI-safe checks (no real Salesforce connection)
Library           OperatingSystem
Library           Collections
Library           BuiltIn
Library           String
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
        @{cmd}=    Create List    cmd.exe    /c    ${SF_CLI}
    ELSE
        @{cmd}=    Create List    ${SF_CLI}
    END

    FOR    ${arg}    IN    @{sf_args}
        Append To List    ${cmd}    ${arg}
    END

    RETURN    ${cmd}


Get Skip Reason
    [Arguments]    ${error}

    # Case 1: Already a dict
    ${is_dict}=    Run Keyword And Return Status    Dictionary Should Contain Key    ${error}    name
    IF    ${is_dict}
        ${name}=    Get From Dictionary    ${error}    name
    ELSE
        # Case 2: Try parsing JSON safely
        ${parsed}=    Run Keyword And Return Status
        ...    Evaluate    __import__("json").loads($error)

        IF    ${parsed}
            ${error}=    Evaluate    __import__("json").loads($error)
            ${name}=     Get From Dictionary    ${error}    name    default=${EMPTY}
        ELSE
            # Case 3: Plain string error name
            ${name}=    Set Variable    ${error}
        END
    END

    IF    '${name}' == 'INVALID_TYPE_FOR_OPERATION'
        RETURN    COUNT_NOT_SUPPORTED
    END

    RETURN    ${name}


Filter Countable Objects
    [Arguments]    @{objects}

    @{filtered}=    Create List

    FOR    ${obj}    IN    @{objects}

        ${is_history}=    Run Keyword And Return Status    Should End With    ${obj}    History
        ${is_feed}=       Run Keyword And Return Status    Should End With    ${obj}    Feed
        ${is_encryption}=   Run Keyword And Return Status    Should Be Equal    ${obj}    DataEncryptionKey
        ${is_apex}=       Run Keyword And Return Status    Should Be Equal    ${obj}    ApexClass

        IF    not ${is_history} and not ${is_feed} and not ${is_encryption} and not ${is_apex}
            Append To List    ${filtered}    ${obj}
        END

    END

    RETURN    ${filtered}


*** Test Cases ***

Smoke - Resource Loads
    Should Not Be Empty    ${SF_CLI}
    Should Be Equal        ${SF_CLI}    sf


Smoke - Build Sf Command Cross Platform
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
    ${fake_output}=    Catenate    SEPARATOR=\n
    ...    Warning: update available
    ...    {
    ...      "status": 0,
    ...      "result": ["Account", "Contact"]
    ...    }

    ${parsed}=    Safe Parse Sf Json    ${fake_output}

    Should Be Equal As Integers    ${parsed}[status]    0
    Length Should Be               ${parsed}[result]    2
    List Should Contain Value      ${parsed}[result]    Account


Smoke - Get Skip Reason - JSON Error
    ${error_json}=    Set Variable    {"name": "INVALID_TYPE_FOR_OPERATION", "message": "Count not supported"}
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