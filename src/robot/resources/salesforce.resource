*** Settings ***
Documentation    Salesforce CLI discovery, query, timeout, and error-classification keywords.
Library          BuiltIn
Library          Collections
Library          DateTime
Library          Process
Library          String
Resource         configuration.resource
Library          ../libraries/SfUtils.py


*** Keywords ***
Check Prerequisites
    [Documentation]    Resolve executables and verify the authenticated Salesforce org.
    Create Directory    ${SCAN_OUTPUT_ROOT}
    ${sf_path}=    Resolve Executable    ${SF_CLI}
    ${python_path}=    Current Python Executable
    VAR    ${SF_CLI}    ${sf_path}    scope=SUITE
    VAR    ${PYTHON}    ${python_path}    scope=SUITE
    Log To Console    Using SF CLI: ${SF_CLI}
    ${version_result}=    Run Process    ${SF_CLI}    --version
    Should Be Equal As Integers
    ...    ${version_result.rc}
    ...    0
    ...    msg=Salesforce CLI failed to execute.\n${version_result.stderr}
    ${org_result}=    Run Process
    ...    ${SF_CLI}
    ...    org
    ...    display
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    Should Be Equal As Integers
    ...    ${org_result.rc}
    ...    0
    ...    msg=Org alias is unavailable or unauthenticated: ${ORG_ALIAS}\n${org_result.stderr}
    ${org_json}=    Safe Parse Sf Json    ${org_result.stdout}
    ${result}=    Get From Dictionary    ${org_json}    result
    ${api_version}=    Get From Dictionary    ${result}    apiVersion
    VAR    ${API_VERSION}    ${api_version}    scope=SUITE
    Log To Console    Connected to ${ORG_ALIAS} (API v${API_VERSION})

Validate Org Alias
    [Documentation]    Require a non-empty Salesforce org alias.
    ${alias}=    Strip String    ${ORG_ALIAS}
    Should Not Be Empty
    ...    ${alias}
    ...    ORG_ALIAS is required. Pass --variable ORG_ALIAS:<your_org>.

Safe Parse Sf Json
    [Documentation]    Parse Salesforce CLI JSON surrounded by diagnostic text.
    [Arguments]    ${raw}
    ${status}    ${data}=    Run Keyword And Ignore Error    Parse Sf Json    ${raw}
    IF    '${status}' == 'PASS'
        RETURN    ${data}
    END
    Fail    Unable to parse sf JSON output: ${data}\nRaw output:\n${raw}

Run Sf Json
    [Documentation]    Run an sf command and return its parsed JSON response.
    [Arguments]    @{command_parts}
    ${result}=    Run Process
    ...    ${SF_CLI}
    ...    @{command_parts}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    Should Be Equal As Integers
    ...    ${result.rc}
    ...    0
    ...    msg=Command failed: sf @{command_parts}\n${result.stderr}
    ${data}=    Safe Parse Sf Json    ${result.stdout}
    RETURN    ${data}

Run Sf Api Request Rest Json
    [Documentation]    Invoke a Salesforce REST resource through sf CLI.
    [Arguments]    ${relative_url}
    ${result}=    Run Process
    ...    ${SF_CLI}
    ...    api
    ...    request
    ...    rest
    ...    ${relative_url}
    ...    --target-org
    ...    ${ORG_ALIAS}
    Should Be Equal As Integers
    ...    ${result.rc}
    ...    0
    ...    msg=Salesforce API call failed:\n${result.stdout}\n${result.stderr}
    ${data}=    Safe Parse Sf Json    ${result.stdout}
    RETURN    ${data}

Get Object Names From List
    [Documentation]    Return the object-name list from sf sobject list JSON.
    [Arguments]    ${list_json}
    ${names}=    Get From Dictionary    ${list_json}    result
    Should Be True    isinstance($names, list)    sf sobject list result must be a list.
    RETURN    ${names}

Deduplicate Object Names
    [Documentation]    Remove duplicate names while preserving discovery order.
    [Arguments]    ${names}
    ${unique}=    Create List
    FOR    ${name}    IN    @{names}
        ${already_present}=    Run Keyword And Return Status
        ...    List Should Contain Value
        ...    ${unique}
        ...    ${name}
        IF    not ${already_present}
            Append To List    ${unique}    ${name}
        END
    END
    RETURN    ${unique}

Filter Countable Objects
    [Documentation]    Compatibility alias for the previous public keyword.
    [Arguments]    @{names}
    ${unique}=    Deduplicate Object Names    ${names}
    RETURN    ${unique}

Get Skip Reason
    [Documentation]    Classify a failed Salesforce CLI response.
    [Arguments]    ${text}
    ${status}    ${data}=    Run Keyword And Ignore Error    Safe Parse Sf Json    ${text}
    IF    '${status}' == 'PASS'
        ${is_dictionary}=    Evaluate    isinstance($data, dict)
        IF    ${is_dictionary}
            ${has_name}=    Run Keyword And Return Status
            ...    Dictionary Should Contain Key
            ...    ${data}
            ...    name
            IF    ${has_name}
                ${name}=    Get From Dictionary    ${data}    name
                ${message}=    Get From Dictionary    ${data}    message    default=${EMPTY}
                IF    'Count operation not supported' in $message
                    RETURN    COUNT_NOT_SUPPORTED
                END
                IF    'Where clauses should contain StatType' in $message
                    RETURN    REQUIRES_WHERE_StatType
                END
                ${is_expected}=    Run Keyword And Return Status
                ...    List Should Contain Value
                ...    ${EXPECTED_SKIP_REASONS}
                ...    ${name}
                IF    ${is_expected}
                    RETURN    ${name}
                END
                ${is_operational}=    Run Keyword And Return Status
                ...    List Should Contain Value
                ...    ${OPERATIONAL_FAILURE_REASONS}
                ...    ${name}
                IF    ${is_operational}
                    RETURN    ${name}
                END
                RETURN    OTHER_ERROR
            END
        END
    END
    @{classified_reasons}=    Combine Lists
    ...    ${EXPECTED_SKIP_REASONS}
    ...    ${OPERATIONAL_FAILURE_REASONS}
    FOR    ${reason}    IN    @{classified_reasons}
        IF    $reason in $text
            RETURN    ${reason}
        END
    END
    RETURN    OTHER_ERROR

Get Max Timeout For Object
    [Documentation]    Return the configured timeout for one object.
    [Arguments]    ${object_name}
    ${is_slow}=    Run Keyword And Return Status
    ...    List Should Contain Value
    ...    ${SLOW_OBJECTS}
    ...    ${object_name}
    IF    ${is_slow}
        RETURN    ${CONNECTEDAPP_TIMEOUT}
    END
    RETURN    ${MAX_QUERY_TIMEOUT_SECONDS}

Get Record Count Safe
    [Documentation]    Query one object and return count, status, and duration.
    [Arguments]    ${object_name}    ${tooling}=${FALSE}
    ${query}=    Set Variable    SELECT COUNT() FROM ${object_name}
    ${arguments}=    Create List    data    query    --query    ${query}
    IF    ${tooling}
        Append To List    ${arguments}    --use-tooling-api
    END
    Append To List    ${arguments}    --target-org    ${ORG_ALIAS}    --json
    ${started}=    Get Current Date    result_format=epoch
    ${process}=    Start Process    ${SF_CLI}    @{arguments}
    ${timeout}=    Get Max Timeout For Object    ${object_name}
    ${poll_interval}=    Convert To Number    ${POLL_INTERVAL_SECONDS}
    WHILE    ${TRUE}
        ${result}=    Wait For Process
        ...    ${process}
        ...    timeout=${poll_interval}
        ...    on_timeout=continue
        IF    $result is not None
            BREAK
        END
        ${now}=    Get Current Date    result_format=epoch
        ${elapsed}=    Evaluate    $now - $started
        IF    ${elapsed} >= ${timeout}
            Terminate Process    ${process}    kill=${TRUE}
            RETURN    ${None}    TIMEOUT    ${elapsed}
        END
    END

    ${finished}=    Get Current Date    result_format=epoch
    ${duration}=    Evaluate    round(float($finished) - float($started), 2)
    IF    ${result.rc} != 0
        ${error_text}=    Catenate    SEPARATOR=\n    ${result.stdout}    ${result.stderr}
        ${reason}=    Get Skip Reason    ${error_text}
        RETURN    ${None}    ${reason}    ${duration}
    END
    ${parse_status}    ${data}=    Run Keyword And Ignore Error
    ...    Safe Parse Sf Json
    ...    ${result.stdout}
    IF    '${parse_status}' != 'PASS'
        RETURN    ${None}    INVALID_JSON_OUTPUT    ${duration}
    END
    ${is_dictionary}=    Evaluate    isinstance($data, dict)
    IF    not ${is_dictionary}
        RETURN    ${None}    INVALID_JSON_STRUCTURE    ${duration}
    END
    ${has_result}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key
    ...    ${data}
    ...    result
    IF    not ${has_result}
        RETURN    ${None}    INVALID_JSON_STRUCTURE    ${duration}
    END
    ${query_result}=    Get From Dictionary    ${data}    result
    ${has_count}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key
    ...    ${query_result}
    ...    totalSize
    IF    not ${has_count}
        RETURN    ${None}    INVALID_JSON_STRUCTURE    ${duration}
    END
    ${count}=    Get From Dictionary    ${query_result}    totalSize
    RETURN    ${count}    OK    ${duration}

Get Tooling Object Names
    [Documentation]    Discover queryable Tooling API objects and return a discovery status.
    ${status}    ${response}=    Run Keyword And Ignore Error
    ...    Run Sf Api Request Rest Json
    ...    /services/data/v${API_VERSION}/tooling/sobjects/
    IF    '${status}' != 'PASS'
        Log To Console    Tooling discovery failed: ${response}
        ${empty}=    Create List
        RETURN    ${empty}    TOOLING_DISCOVERY_FAILED
    END
    ${has_objects}=    Run Keyword And Return Status
    ...    Dictionary Should Contain Key
    ...    ${response}
    ...    sobjects
    IF    not ${has_objects}
        Log To Console    Tooling discovery returned no sobjects collection.
        ${empty}=    Create List
        RETURN    ${empty}    TOOLING_DISCOVERY_FAILED
    END
    ${sobjects}=    Get From Dictionary    ${response}    sobjects
    ${names}=    Create List
    FOR    ${object}    IN    @{sobjects}
        ${name}=    Get From Dictionary    ${object}    name    default=${EMPTY}
        ${queryable}=    Get From Dictionary    ${object}    queryable    default=${FALSE}
        IF    $name and $queryable
            Append To List    ${names}    ${name}
        END
    END
    IF    not $names
        Log To Console    Tooling discovery returned no queryable objects.
        RETURN    ${names}    TOOLING_DISCOVERY_FAILED
    END
    RETURN    ${names}    OK
