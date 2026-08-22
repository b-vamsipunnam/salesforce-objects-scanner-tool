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
    ${version_result}=    Run Sf Command Captured    --version
    ${version_error}=    Get Safe Sf Error Summary
    ...    ${version_result.stdout}
    ...    ${version_result.stderr}
    Should Be Equal As Integers
    ...    ${version_result.rc}
    ...    0
    ...    msg=Salesforce CLI failed to execute.\n${version_error}
    ${org_result}=    Run Sf Command Captured
    ...    org
    ...    display
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    ${org_error}=    Get Safe Sf Error Summary    ${org_result.stdout}    ${org_result.stderr}
    Should Be Equal As Integers
    ...    ${org_result.rc}
    ...    0
    ...    msg=Org alias is unavailable or unauthenticated: ${ORG_ALIAS}\n${org_error}
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
    ${details}=    Get Sf Error Details    ${raw}
    ${safe_details}=    Evaluate    json.dumps($details, ensure_ascii=False)    modules=json
    Fail    Unable to parse sf JSON output: ${data}\nSanitized details: ${safe_details}

Run Sf Json
    [Documentation]    Run an sf command and return its parsed JSON response.
    [Arguments]    @{command_parts}
    ${result}=    Run Sf Command Captured
    ...    @{command_parts}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    ${safe_error}=    Get Safe Sf Error Summary    ${result.stdout}    ${result.stderr}
    Should Be Equal As Integers
    ...    ${result.rc}
    ...    0
    ...    msg=Command failed: sf @{command_parts}\n${safe_error}
    ${data}=    Safe Parse Sf Json    ${result.stdout}
    RETURN    ${data}

Run Sf Api Request Rest Json
    [Documentation]    Invoke a Salesforce REST resource through sf CLI.
    [Arguments]    ${relative_url}
    ${result}=    Run Sf Command Captured
    ...    api
    ...    request
    ...    rest
    ...    ${relative_url}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ${safe_error}=    Get Safe Sf Error Summary    ${result.stdout}    ${result.stderr}
    Should Be Equal As Integers
    ...    ${result.rc}
    ...    0
    ...    msg=Salesforce API call failed:\n${safe_error}
    ${data}=    Safe Parse Sf Json    ${result.stdout}
    RETURN    ${data}

Get Safe Sf Error Summary
    [Documentation]    Return sanitized JSON error evidence safe for logs and console output.
    [Arguments]    ${stdout}=${EMPTY}    ${stderr}=${EMPTY}
    ${raw}=    Catenate    SEPARATOR=\n    ${stdout}    ${stderr}
    ${details}=    Get Sf Error Details    ${raw}
    ${summary}=    Evaluate    json.dumps($details, ensure_ascii=False)    modules=json
    RETURN    ${summary}

Run Sf Command Captured
    [Documentation]    Run sf with file-backed output so large JSON responses cannot fill OS pipes.
    [Arguments]    @{command_parts}
    ${capture_id}=    Evaluate    __import__('uuid').uuid4().hex
    ${stdout_path}=    Normalize Path    ${SCAN_OUTPUT_ROOT}${/}.sf-${capture_id}.stdout
    ${stderr_path}=    Normalize Path    ${SCAN_OUTPUT_ROOT}${/}.sf-${capture_id}.stderr
    TRY
        ${result}=    Run Process
        ...    ${SF_CLI}
        ...    @{command_parts}
        ...    stdout=${stdout_path}
        ...    stderr=${stderr_path}
        ...    timeout=${SF_COMMAND_TIMEOUT_SECONDS}
        ...    on_timeout=kill
        # Access the properties before cleanup so Robot caches the file contents.
        ${stdout}=    Set Variable    ${result.stdout}
        ${stderr}=    Set Variable    ${result.stderr}
        RETURN    ${result}
    FINALLY
        Remove File    ${stdout_path}
        Remove File    ${stderr_path}
    END

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
    ${poll_interval}=    Convert To Number    ${POLL_INTERVAL_SECONDS}
    ${retry_limit}=    Convert To Integer    ${SF_TRANSIENT_RETRIES}
    ${max_attempts}=    Evaluate    $retry_limit + 1
    FOR    ${attempt}    IN RANGE    1    ${max_attempts + 1}
        ${attempt_started}=    Get Current Date    result_format=epoch
        ${process}=    Start Process    ${SF_CLI}    @{arguments}
        ${timed_out}=    Set Variable    ${FALSE}
        WHILE    ${TRUE}
            ${result}=    Wait For Process
            ...    ${process}
            ...    timeout=${poll_interval}
            ...    on_timeout=continue
            IF    $result is not None
                BREAK
            END
            ${now}=    Get Current Date    result_format=epoch
            ${attempt_elapsed}=    Evaluate    $now - $attempt_started
            IF    ${attempt_elapsed} >= ${timeout}
                Terminate Process    ${process}    kill=${TRUE}
                ${timed_out}=    Set Variable    ${TRUE}
                BREAK
            END
        END
        ${finished}=    Get Current Date    result_format=epoch
        ${duration}=    Evaluate    round(float($finished) - float($started), 2)
        IF    ${timed_out}
            ${details}=    Create Dictionary
            ...    name=TIMEOUT
            ...    message=Query exceeded ${timeout} seconds on attempt ${attempt}.
            RETURN    ${None}    TIMEOUT    ${duration}    ${details}
        END
        IF    ${result.rc} != 0
            ${error_text}=    Catenate    SEPARATOR=\n    ${result.stdout}    ${result.stderr}
            ${reason}=    Get Skip Reason    ${error_text}    ${object_name}    ${tooling}
            ${details}=    Get Sf Error Details    ${error_text}
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
        ${parse_status}    ${data}=    Run Keyword And Ignore Error
        ...    Safe Parse Sf Json
        ...    ${result.stdout}
        IF    '${parse_status}' != 'PASS'
            ${details}=    Get Sf Error Details    ${result.stdout}
            RETURN    ${None}    INVALID_JSON_OUTPUT    ${duration}    ${details}
        END
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
