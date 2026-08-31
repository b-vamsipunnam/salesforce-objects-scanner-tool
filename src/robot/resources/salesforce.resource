*** Settings ***
Documentation    Salesforce CLI discovery, query, timeout, and error-classification keywords.
Library          BuiltIn
Library          Collections
Library          DateTime
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
    @{version_arguments}=    Create List    --version
    ${version_result}=    Run Sf Command Safely
    ...    ${SF_CLI}
    ...    ${version_arguments}
    ...    ${SCAN_OUTPUT_ROOT}
    ...    ${SF_COMMAND_TIMEOUT_SECONDS}
    ...    ${FALSE}
    Should Be True    ${version_result}[ok]    Salesforce CLI failed to execute: ${version_result}[details]
    ${versions}=    Run Sf Api Request Rest Json    /services/data/
    ${api_version}=    Get Latest Sf Api Version    ${versions}
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
    ${details}=    Get Sf Error Details    ${raw}
    ${safe_details}=    Evaluate    json.dumps($details, ensure_ascii=False)    modules=json
    Fail    Unable to parse sf JSON output: ${data}\nSanitized details: ${safe_details}

Run Sf Json
    [Documentation]    Run an sf command and return its parsed JSON response.
    [Arguments]    @{command_parts}
    ${arguments}=    Create List    @{command_parts}    --target-org    ${ORG_ALIAS}    --json
    ${result}=    Run Sf Command Safely
    ...    ${SF_CLI}
    ...    ${arguments}
    ...    ${SCAN_OUTPUT_ROOT}
    ...    ${SF_COMMAND_TIMEOUT_SECONDS}
    Should Be True    ${result}[ok]    Command failed: sf @{command_parts}\n${result}[details]
    RETURN    ${result}[data]

Run Sf Api Request Rest Json
    [Documentation]    Invoke a Salesforce REST resource through sf CLI.
    [Arguments]    ${relative_url}
    ${arguments}=    Create List
    ...    api
    ...    request
    ...    rest
    ...    ${relative_url}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ${result}=    Run Sf Command Safely
    ...    ${SF_CLI}
    ...    ${arguments}
    ...    ${SCAN_OUTPUT_ROOT}
    ...    ${SF_COMMAND_TIMEOUT_SECONDS}
    Should Be True    ${result}[ok]    Salesforce API call failed: ${result}[details]
    RETURN    ${result}[data]

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
    [Arguments]    ${text}    ${object_name}=${EMPTY}    ${tooling}=${FALSE}
    ${known_count_limitation}=    Is Known Unknown Exception Count Limitation
    ...    ${object_name}
    ...    ${tooling}
    ${reason}=    Classify Sf Error
    ...    ${text}
    ...    ${object_name}
    ...    ${tooling}
    ...    ${ALLOW_DISABLED_DATACLOUD}
    ...    ${known_count_limitation}
    RETURN    ${reason}

Is Known Unknown Exception Count Limitation
    [Documentation]    Identify object-specific COUNT() limitations reported by Salesforce as UNKNOWN_EXCEPTION.
    [Arguments]    ${object_name}    ${tooling}=${FALSE}
    IF    ${tooling}
        ${known}=    Run Keyword And Return Status
        ...    List Should Contain Value
        ...    ${KNOWN_UNKNOWN_TOOLING_OBJECTS}
        ...    ${object_name}
        RETURN    ${known}
    END
    ${known}=    Run Keyword And Return Status
    ...    List Should Contain Value
    ...    ${KNOWN_UNKNOWN_DATA_OBJECTS}
    ...    ${object_name}
    RETURN    ${known}

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
    ${timeout}=    Get Max Timeout For Object    ${object_name}
    ${retry_limit}=    Convert To Integer    ${SF_TRANSIENT_RETRIES}
    ${max_attempts}=    Evaluate    $retry_limit + 1
    FOR    ${attempt}    IN RANGE    1    ${max_attempts + 1}
        ${result}=    Run Sf Command Safely
        ...    ${SF_CLI}
        ...    ${arguments}
        ...    ${SCAN_OUTPUT_ROOT}
        ...    ${timeout}
        ${finished}=    Get Current Date    result_format=epoch
        ${duration}=    Evaluate    round(float($finished) - float($started), 2)
        IF    ${result}[timed_out]
            ${details}=    Set Variable    ${result}[details]
            Set To Dictionary    ${details}    attempts=${attempt}
            RETURN    ${None}    TIMEOUT    ${duration}    ${details}
        END
        IF    not ${result}[ok]
            ${details}=    Set Variable    ${result}[details]
            ${safe_error}=    Evaluate    json.dumps($details, ensure_ascii=False)    modules=json
            ${reason}=    Get Skip Reason    ${safe_error}    ${object_name}    ${tooling}
            Set To Dictionary    ${details}    attempts=${attempt}
            ${retry}=    Should Retry Sf Failure
            ...    ${reason}
            ...    ${details}
            ...    ${object_name}
            ...    ${tooling}
            ...    ${attempt}
            IF    ${retry}
                ${delay}=    Evaluate    float($SF_RETRY_BACKOFF_SECONDS) * (2 ** ($attempt - 1))
                Log To Console
                ...    ${object_name}: retrying ${reason} in ${delay}s (attempt ${attempt + 1}/${max_attempts})
                Sleep    ${delay}
                CONTINUE
            END
            RETURN    ${None}    ${reason}    ${duration}    ${details}
        END
        ${data}=    Set Variable    ${result}[data]
        ${is_dictionary}=    Evaluate    isinstance($data, dict)
        IF    not ${is_dictionary}
            ${details}=    Create Dictionary
            ...    name=INVALID_JSON_STRUCTURE
            ...    message=Salesforce CLI response was not a JSON object.
            RETURN    ${None}    INVALID_JSON_STRUCTURE    ${duration}    ${details}
        END
        ${has_result}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key
        ...    ${data}
        ...    result
        IF    not ${has_result}
            ${details}=    Create Dictionary
            ...    name=INVALID_JSON_STRUCTURE
            ...    message=Salesforce CLI response did not contain result.
            RETURN    ${None}    INVALID_JSON_STRUCTURE    ${duration}    ${details}
        END
        ${query_result}=    Get From Dictionary    ${data}    result
        ${has_count}=    Run Keyword And Return Status
        ...    Dictionary Should Contain Key
        ...    ${query_result}
        ...    totalSize
        IF    not ${has_count}
            ${details}=    Create Dictionary
            ...    name=INVALID_JSON_STRUCTURE
            ...    message=Salesforce CLI result did not contain totalSize.
            RETURN    ${None}    INVALID_JSON_STRUCTURE    ${duration}    ${details}
        END
        ${count}=    Get From Dictionary    ${query_result}    totalSize
        ${details}=    Create Dictionary
        RETURN    ${count}    OK    ${duration}    ${details}
    END
    Fail    Query retry loop ended unexpectedly for ${object_name}.

Should Retry Sf Failure
    [Documentation]    Retry configured failures only when their sanitized evidence is transient.
    [Arguments]    ${reason}    ${details}    ${object_name}    ${tooling}    ${attempt}
    ${is_transient}=    Run Keyword And Return Status
    ...    List Should Contain Value
    ...    ${TRANSIENT_FAILURE_REASONS}
    ...    ${reason}
    ${retry_limit}=    Convert To Integer    ${SF_TRANSIENT_RETRIES}
    ${within_limit}=    Evaluate    int($attempt) <= $retry_limit
    ${has_transient_evidence}=    Is Sf Failure Retryable
    ...    ${reason}
    ...    ${details}
    ...    ${object_name}
    ...    ${tooling}
    ${should_retry}=    Evaluate    $is_transient and $within_limit and $has_transient_evidence
    RETURN    ${should_retry}

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
