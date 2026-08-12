*** Settings ***
Documentation    Robot-native Pabot batching, per-object artifacts, and scan-quality validation.
Library          BuiltIn
Library          Collections
Library          OperatingSystem
Library          Process
Library          String
Resource         configuration.resource
Resource         salesforce.resource


*** Keywords ***
Run Object Queries With Pabot
    [Documentation]    Execute balanced object batches with Pabot and consolidate their artifacts.
    [Arguments]    ${data_objects}    ${tooling_objects}    ${run_directory}
    ${parallel_directory}=    Normalize Path    ${run_directory}${/}pabot
    ${artifact_directory}=    Normalize Path    ${parallel_directory}${/}artifacts
    ${worker_directory}=    Normalize Path    ${parallel_directory}${/}workers
    ${pabot_output_directory}=    Normalize Path    ${parallel_directory}${/}results
    ${console_log}=    Normalize Path    ${parallel_directory}${/}pabot-console.log
    Create Directory    ${artifact_directory}
    Create Directory    ${worker_directory}
    Create Directory    ${pabot_output_directory}
    ${worker_count}=    Generate Pabot Worker Suites
    ...    ${worker_directory}
    ...    ${data_objects}
    ...    ${tooling_objects}
    ${total}=    Evaluate    len($data_objects) + len($tooling_objects)
    Log To Console
    ...    Running ${total} object queries in ${worker_count} balanced Pabot suites with ${PABOT_PROCESSES} processes...
    ${pabot_result}=    Run Process
    ...    ${PYTHON}
    ...    -m
    ...    pabot.pabot
    ...    --processes
    ...    ${PABOT_PROCESSES}
    ...    --outputdir
    ...    ${pabot_output_directory}
    ...    --variable
    ...    ORG_ALIAS:${ORG_ALIAS}
    ...    --variable
    ...    SF_CLI:${SF_CLI}
    ...    --variable
    ...    ARTIFACT_DIR:${artifact_directory}
    ...    --variable
    ...    VERBOSE_OBJECT_RESULTS:${VERBOSE_OBJECT_RESULTS}
    ...    --variable
    ...    SF_TRANSIENT_RETRIES:${SF_TRANSIENT_RETRIES}
    ...    --variable
    ...    SF_RETRY_BACKOFF_SECONDS:${SF_RETRY_BACKOFF_SECONDS}
    ...    --variable
    ...    ALLOW_DISABLED_DATACLOUD:${ALLOW_DISABLED_DATACLOUD}
    ...    ${worker_directory}
    ...    stdout=${console_log}
    ...    stderr=STDOUT
    IF    ${pabot_result.rc} != 0
        ${console_output}=    Get File    ${console_log}
        Log To Console    ${console_output}
        Fail    Pabot object batches failed. See ${pabot_output_directory}.
    END
    ${data_results}    ${tooling_results}    ${skipped_reasons}    ${skipped_details}    ${durations}=
    ...    Load Query Artifacts
    ...    ${artifact_directory}
    ...    ${data_objects}
    ...    ${tooling_objects}
    RETURN
    ...    ${data_results}
    ...    ${tooling_results}
    ...    ${skipped_reasons}
    ...    ${skipped_details}
    ...    ${durations}

Generate Pabot Worker Suites
    [Documentation]    Create balanced Robot suites so Pabot reuses a process for many objects.
    [Arguments]    ${worker_directory}    ${data_objects}    ${tooling_objects}
    ${total}=    Evaluate    len($data_objects) + len($tooling_objects)
    Should Be True    ${total} > 0    Salesforce discovery returned no objects to process.
    ${requested_shards}=    Evaluate    $PABOT_PROCESSES * $PABOT_SHARDS_PER_PROCESS
    ${shard_count}=    Evaluate    min($total, $requested_shards)
    ${data_shards}=    Create List
    ${tooling_shards}=    Create List
    FOR    ${index}    IN RANGE    ${shard_count}
        ${data_shard}=    Create List
        ${tooling_shard}=    Create List
        Append To List    ${data_shards}    ${data_shard}
        Append To List    ${tooling_shards}    ${tooling_shard}
    END
    FOR    ${index}    ${object_name}    IN ENUMERATE    @{data_objects}
        ${shard_index}=    Evaluate    $index % $shard_count
        ${shard}=    Get From List    ${data_shards}    ${shard_index}
        Append To List    ${shard}    ${object_name}
    END
    ${data_count}=    Get Length    ${data_objects}
    FOR    ${index}    ${object_name}    IN ENUMERATE    @{tooling_objects}
        ${work_index}=    Evaluate    $data_count + $index
        ${shard_index}=    Evaluate    $work_index % $shard_count
        ${shard}=    Get From List    ${tooling_shards}    ${shard_index}
        Append To List    ${shard}    ${object_name}
    END
    ${resource_path}=    Normalize Path    ${CURDIR}${/}keywords.robot
    ${resource_path}=    Replace String    ${resource_path}    ${BACKSLASH}    /
    FOR    ${index}    IN RANGE    ${shard_count}
        ${data_shard}=    Get From List    ${data_shards}    ${index}
        ${tooling_shard}=    Get From List    ${tooling_shards}    ${index}
        ${suite_path}=    Normalize Path    ${worker_directory}${/}object_batch_${index}.robot
        Write Pabot Worker Suite
        ...    ${suite_path}
        ...    ${resource_path}
        ...    ${data_shard}
        ...    ${tooling_shard}
    END
    RETURN    ${shard_count}

Write Pabot Worker Suite
    [Documentation]    Write one generated Robot suite containing an assigned object batch.
    [Arguments]    ${suite_path}    ${resource_path}    ${data_objects}    ${tooling_objects}
    ${resource_line}=    Catenate    SEPARATOR=${SPACE * 4}    Resource    ${resource_path}
    Create File    ${suite_path}    *** Settings ***\n
    Append To File    ${suite_path}    ${resource_line}\n\n
    Append To File    ${suite_path}    *** Variables ***\n
    Append To File    ${suite_path}    \@{DATA_OBJECTS}\n
    FOR    ${object_name}    IN    @{data_objects}
        Should Match Regexp    ${object_name}    ^[A-Za-z][A-Za-z0-9_]*$
        Append To File    ${suite_path}    ${ELLIPSIS}${SPACE * 4}${object_name}\n
    END
    Append To File    ${suite_path}    \@{TOOLING_OBJECTS}\n
    FOR    ${object_name}    IN    @{tooling_objects}
        Should Match Regexp    ${object_name}    ^[A-Za-z][A-Za-z0-9_]*$
        Append To File    ${suite_path}    ${ELLIPSIS}${SPACE * 4}${object_name}\n
    END
    ${execution_line}=    Catenate
    ...    SEPARATOR=${SPACE * 4}
    ...    Execute Object Query Batch
    ...    \${DATA_OBJECTS}
    ...    \${TOOLING_OBJECTS}
    ...    \${ARTIFACT_DIR}
    Append To File    ${suite_path}    \n*** Test Cases ***\n
    Append To File    ${suite_path}    Query Assigned Object Batch\n
    Append To File    ${suite_path}    ${SPACE * 4}${execution_line}\n

Execute Object Query Batch
    [Documentation]    Query every standard and Tooling object assigned to this Pabot suite.
    [Arguments]    ${data_objects}    ${tooling_objects}    ${artifact_directory}
    FOR    ${object_name}    IN    @{data_objects}
        Execute Object Query Worker    ${object_name}    ${FALSE}    ${artifact_directory}
    END
    FOR    ${object_name}    IN    @{tooling_objects}
        Execute Object Query Worker    ${object_name}    ${TRUE}    ${artifact_directory}
    END

Execute Object Query Worker
    [Documentation]    Query one object, convert unexpected failures, and persist its artifact.
    [Arguments]    ${object_name}    ${tooling}    ${artifact_directory}
    ${status}    ${query_result}=    Run Keyword And Ignore Error
    ...    Get Record Count Safe
    ...    ${object_name}
    ...    tooling=${tooling}
    IF    '${status}' == 'PASS'
        ${count}=    Set Variable    ${query_result}[0]
        ${reason}=    Set Variable    ${query_result}[1]
        ${duration}=    Set Variable    ${query_result}[2]
        ${details}=    Set Variable    ${query_result}[3]
    ELSE
        ${count}=    Set Variable    ${None}
        ${reason}=    Set Variable    WORKER_ERROR
        ${duration}=    Set Variable    ${0.0}
        ${details}=    Set Variable    ${query_result}
        Log To Console    ${object_name}: unexpected worker error: ${query_result}
        Log    ${query_result}    level=WARN
    END
    Save Query Artifact
    ...    ${artifact_directory}
    ...    ${object_name}
    ...    ${tooling}
    ...    ${count}
    ...    ${reason}
    ...    ${duration}
    ...    ${details}
    ${should_log}=    Should Log Object Result    ${reason}
    IF    ${should_log}
        IF    '${reason}' == 'OK'
            Log To Console    ${object_name}: ${count} (t=${duration}s)
        ELSE
            Log To Console    ${object_name}: SKIPPED (${reason}) (t=${duration}s)
        END
    END

Should Log Object Result
    [Documentation]    Return true for skips or when detailed successful-object output is enabled.
    [Arguments]    ${reason}    ${verbose_value}=${VERBOSE_OBJECT_RESULTS}
    IF    '${reason}' != 'OK'
        RETURN    ${TRUE}
    END
    ${verbose}=    Convert To Boolean    ${verbose_value}
    RETURN    ${verbose}

Get Query Artifact Path
    [Documentation]    Return the deterministic artifact path for one object identity.
    [Arguments]    ${artifact_directory}    ${object_name}    ${tooling}
    ${kind}=    Set Variable If    ${tooling}    tooling    data
    ${path}=    Normalize Path    ${artifact_directory}${/}${kind}__${object_name}.json
    RETURN    ${path}

Save Query Artifact
    [Documentation]    Write one result through a temporary file and atomically move it into place.
    [Arguments]    ${artifact_directory}
    ...    ${object_name}
    ...    ${tooling}
    ...    ${count}
    ...    ${reason}
    ...    ${duration}
    ...    ${details}=${EMPTY}
    ${path}=    Get Query Artifact Path    ${artifact_directory}    ${object_name}    ${tooling}
    ${temporary_path}=    Set Variable    ${path}.tmp
    ${payload}=    Create Dictionary
    ...    object_name=${object_name}
    ...    tooling=${tooling}
    ...    count=${count}
    ...    reason=${reason}
    ...    duration=${duration}
    ...    details=${details}
    ${json}=    Evaluate    json.dumps($payload, ensure_ascii=False)    modules=json
    Create File    ${temporary_path}    ${json}
    Move File    ${temporary_path}    ${path}

Read Query Artifact
    [Documentation]    Read and validate one expected artifact.
    [Arguments]    ${artifact_directory}    ${object_name}    ${tooling}
    ${path}=    Get Query Artifact Path    ${artifact_directory}    ${object_name}    ${tooling}
    File Should Exist    ${path}
    ${raw}=    Get File    ${path}
    ${payload}=    Safe Parse Sf Json    ${raw}
    Dictionary Should Contain Key    ${payload}    object_name
    Dictionary Should Contain Key    ${payload}    tooling
    Dictionary Should Contain Key    ${payload}    count
    Dictionary Should Contain Key    ${payload}    reason
    Dictionary Should Contain Key    ${payload}    duration
    Dictionary Should Contain Key    ${payload}    details
    Should Be Equal    ${payload}[object_name]    ${object_name}
    ${actual_tooling}=    Convert To Boolean    ${payload}[tooling]
    Should Be Equal    ${actual_tooling}    ${tooling}
    ${reason}=    Convert To String    ${payload}[reason]
    Should Not Be Empty    ${reason}
    ${duration}=    Convert To Number    ${payload}[duration]
    Should Be True    ${duration} >= 0    Artifact duration must be non-negative.
    IF    '${reason}' == 'OK'
        Should Be True
        ...    isinstance($payload["count"], int) and not isinstance($payload["count"], bool)
        ...    Successful artifact count must be an integer.
        ${count}=    Set Variable    ${payload}[count]
        Should Be True    ${count} >= 0    Successful artifact count must be non-negative.
    ELSE
        Should Be Equal
        ...    ${payload}[count]
        ...    ${None}
        ...    Skipped artifact count must be null.
        ${count}=    Set Variable    ${None}
    END
    RETURN    ${count}    ${reason}    ${duration}    ${payload}[details]

Load Query Artifacts
    [Documentation]    Validate completeness and build the four report dictionaries.
    [Arguments]    ${artifact_directory}    ${data_objects}    ${tooling_objects}
    ${expected}=    Evaluate    len($data_objects) + len($tooling_objects)
    ${actual}=    Count Files In Directory    ${artifact_directory}    pattern=*.json
    Should Be Equal As Integers
    ...    ${actual}
    ...    ${expected}
    ...    Parallel result count does not match the scheduled object count.
    ${data_results}=    Create Dictionary
    ${tooling_results}=    Create Dictionary
    ${skipped_reasons}=    Create Dictionary
    ${skipped_details}=    Create Dictionary
    ${durations}=    Create Dictionary
    FOR    ${object_name}    IN    @{data_objects}
        ${count}    ${reason}    ${duration}    ${details}=    Read Query Artifact
        ...    ${artifact_directory}
        ...    ${object_name}
        ...    ${FALSE}
        Set To Dictionary    ${durations}    ${object_name}=${duration}
        IF    '${reason}' == 'OK'
            Set To Dictionary    ${data_results}    ${object_name}=${count}
        ELSE
            Set To Dictionary    ${skipped_reasons}    ${object_name}=${reason}
            Set To Dictionary    ${skipped_details}    ${object_name}=${details}
        END
    END
    FOR    ${object_name}    IN    @{tooling_objects}
        ${count}    ${reason}    ${duration}    ${details}=    Read Query Artifact
        ...    ${artifact_directory}
        ...    ${object_name}
        ...    ${TRUE}
        Set To Dictionary    ${durations}    TOOLING::${object_name}=${duration}
        IF    '${reason}' == 'OK'
            Set To Dictionary    ${tooling_results}    ${object_name}=${count}
        ELSE
            Set To Dictionary    ${skipped_reasons}    TOOLING::${object_name}=${reason}
            Set To Dictionary    ${skipped_details}    TOOLING::${object_name}=${details}
        END
    END
    RETURN    ${data_results}    ${tooling_results}    ${skipped_reasons}    ${skipped_details}    ${durations}

Get Operational Failures
    [Documentation]    Return skipped entries that indicate an unhealthy scan rather than unsupported objects.
    [Arguments]    ${skipped_reasons}
    ${failures}=    Create Dictionary
    FOR    ${object_name}    ${reason}    IN    &{skipped_reasons}
        ${is_expected}=    Run Keyword And Return Status
        ...    List Should Contain Value
        ...    ${EXPECTED_SKIP_REASONS}
        ...    ${reason}
        IF    not ${is_expected}
            Set To Dictionary    ${failures}    ${object_name}=${reason}
        END
    END
    RETURN    ${failures}

Validate Scan Quality
    [Documentation]    Fail after reports are saved when operational failures make the scan incomplete.
    [Arguments]    ${skipped_reasons}    ${fail_on_errors}=${FAIL_ON_OPERATIONAL_ERRORS}
    ${failures}=    Get Operational Failures    ${skipped_reasons}
    ${failure_count}=    Get Length    ${failures}
    IF    $fail_on_errors and $failure_count > 0
        ${details}=    Evaluate    json.dumps($failures, indent=2)    modules=json
        ${message}=    Catenate
        ...    SEPARATOR=${SPACE}
        ...    Scan reports were saved, but ${failure_count} operational failures
        ...    make the results incomplete:
        Fail    ${message}\n${details}
    END
