*** Settings ***
Documentation                                   Retrieve record counts for Salesforce objects using Salesforce CLI (sf).
...                                             Filters noisy objects, limits runtime, uses timeout protection (polling).
...                                             Enhancements:
...                                             - Parses sf JSON error payload for better skip reasons
...                                             - Logs per-object duration (seconds)
...                                             - Adds early-skip lists for known "count not supported" objects
Library                                         OperatingSystem
Library                                         Collections
Library                                         BuiltIn
Library                                         Process
Library                                         DateTime
Library                                         String

*** Variables ***
${ORG_ALIAS}                                    DeveloperOrg
# Windows execution
${SF_CLI}                                       sf
${PYTHON}                                       python
${OUTPUT_DIR}                                   ${EXECDIR}${/}output
${OUTPUT_FILENAME}                              SF_Objects
${DELAY_SECONDS}                                0.1
${MAX_QUERY_TIMEOUT_SECONDS}                    120
${POLL_INTERVAL_SECONDS}                        1.0
${CONNECTEDAPP_TIMEOUT}                         180
@{SLOW_OBJECTS}                                 ConnectedApplication
${INCLUDE_TOOLING}                              ${TRUE}
${DISCOVER_TOOLING_OBJECTS}                     ${TRUE}
@{TOOLING_OBJECTS}                              ApexClass    ApexTrigger    CustomField    ValidationRule
...                                             ApexPage      ApexComponent  CustomObject   Profile
...                                             PermissionSet  EntityDefinition
# Known "not countable" / restricted objects (pre-filter)
@{NON_COUNTABLE_OBJECTS}                        AggregateResult    ApiEventStream    AsyncOperationStatus
...                                             AttachedContentDocument    CombinedAttachment
...                                             BulkApiResultEventStore
...                                             ApexTypeImplementor    AppTabMember    ColorDefinition
...                                             ContentDocumentLink
...                                             ContentFolderItem    ContentFolderMember
# Known objects where COUNT() is not supported
@{COUNT_NOT_SUPPORTED_OBJECTS}                  DataEncryptionKey
# Known objects that require additional WHERE clause
@{REQUIRES_WHERE_OBJECTS}                       DataStatistics
@{TEMP_FILES}                                   PIPE    log.html    output.xml    report.html
${RUN NAME}                                     Run_

*** Keywords ***
Check Prerequisites
    [Documentation]                             Ensure Salesforce CLI is installed and org alias is authenticated.
    Create Directory                            ${OUTPUT_DIR}
    ${where_res}=                               Run Process                      where    sf    stdout=PIPE    stderr=PIPE
    Should Be Equal As Integers                 ${where_res.rc}    0             msg=Salesforce CLI (sf) not found in PATH.
    @{lines}=                                   Split To Lines                   ${where_res.stdout}
    ${sf_path}=                                 Set Variable                     ${EMPTY}
    FOR    ${line}    IN    @{lines}
           ${is_cmd}=                           Run Keyword And Return Status    Should End With        ${line}    .cmd
           IF    ${is_cmd}
                 ${sf_path}=                    Set Variable                     ${line}
                 Exit For Loop
           END
    END
    Should Not Be Empty                         ${sf_path}                       msg=Could not resolve sf.cmd executable.
    Set Suite Variable                          ${SF_CLI}                        ${sf_path}
    Log To Console                              Using SF CLI: ${SF_CLI}
    ${ver_res}=                                 Run Process                      ${SF_CLI}    --version    stdout=PIPE    stderr=PIPE
    Should Be Equal As Integers                 ${ver_res.rc}    0               msg=Salesforce CLI failed to execute.\n${ver_res.stderr}
    ${org_res}=                                 Run Process
    ...    ${SF_CLI}
    ...    org
    ...    display
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    ...    stdout=PIPE
    ...    stderr=PIPE
    Should Be Equal As Integers                 ${org_res.rc}       0           msg=Org alias not found or not authenticated: ${ORG_ALIAS}\n${org_res.stderr}
    ${json_obj}=                                Safe Parse Sf Json              ${org_res.stdout}
    ${result_dict}=                             Get From Dictionary             ${json_obj}         result
    ${api_version}=                             Get From Dictionary             ${result_dict}      apiVersion
    Set Suite Variable                          ${API_VERSION}                  ${api_version}
    Log To Console                              Connected to ${ORG_ALIAS} (API v${API_VERSION})

Safe Parse Sf Json
    [Arguments]                                 ${raw}
    Should Not Be Empty                         ${raw}                          No output returned from sf.
    ${status1}    ${data1}=                     Run Keyword And Ignore Error    Evaluate    json.loads($raw)    modules=json
    IF    '${status1}' == 'PASS'
           RETURN    ${data1}
    END
    ${index}=                                   Evaluate                        $raw.find('{')
    Run Keyword If    ${index} == -1            Fail                            No JSON object found in output:\n${raw}
    ${clean}=                                   Evaluate                        $raw[$index:]
    ${status2}    ${data2}=                     Run Keyword And Ignore Error    Evaluate    json.loads($clean)    modules=json
    IF    '${status2}' == 'PASS'
           RETURN    ${data2}
    END
    Fail                                        Unable to parse sf JSON output.\nRaw output:\n${raw}

Run Sf Json
    [Documentation]                             Run an sf command and return parsed JSON dict.
    [Arguments]                                 @{command_parts}
    ${res}=                                     Run Process
    ...    ${SF_CLI}
    ...    @{command_parts}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    ...    stdout=PIPE
    ...    stderr=PIPE
    Should Be Equal As Integers                 ${res.rc}       0               msg=Command failed: sf @{command_parts}\n${res.stderr}
    ${data}=                                    Safe Parse Sf Json              ${res.stdout}
    RETURN                                      ${data}

Run Sf Command
    [Documentation]                             Execute Salesforce CLI command and return rc, stdout, stderr.
    [Arguments]                                 @{args}
    Log                                         Running: ${SF_CLI} @{args}
    ${result}=                                  Run Process
    ...    ${SF_CLI}
    ...    @{args}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    stdout=PIPE
    ...    stderr=PIPE
    ${rc}=                                      Set Variable                    ${result.rc}
    ${out}=                                     Set Variable                    ${result.stdout}
    ${err}=                                     Set Variable                    ${result.stderr}
    RETURN    ${rc}    ${out}    ${err}


Run Sf Api Request Rest Json
    [Documentation]                             Call Salesforce REST endpoint via sf CLI and return parsed JSON dict.
    [Arguments]                                 ${relative_url}
    ${rc}    ${out}    ${err}=                  Run Sf Command
    ...    api
    ...    request
    ...    rest
    ...    ${relative_url}
    Should Be Equal As Integers                 ${rc}    0                      SF API call failed:\n${out}\n${err}
    ${status}    ${data}=                       Run Keyword And Ignore Error    Safe Parse Sf Json          ${out}
    IF    '${status}' != 'PASS'
           Fail    Could not parse JSON from sf response:\n${out}
    END
    RETURN                                      ${data}

Get Object Names From List
    [Documentation]                             sf sobject list --json => {"result": ["Account", ...]}.
    [Arguments]                                 ${list_json}
    @{names}=                                   Collections.Get From Dictionary             ${list_json}    result
    RETURN                                      ${names}

Filter Countable Objects
    [Documentation]                             Remove noisy/high-volume platform objects + known restricted objects.
    [Arguments]                                 @{names}
    @{suffixes}=                                Create List
    ...    History
    ...    Feed
    ...    Share
    ...    ChangeEvent
    ...    Event
    ...    Tag
    ...    Vote
    ...    LoginEvent
    ...    __mdt
    ...    __b
    ...    __kav
    ...    __x

    @{keep}=                                    Create List
    FOR    ${n}    IN    @{names}
           ${blocked}=                          Run Keyword And Return Status               List Should Contain Value    ${NON_COUNTABLE_OBJECTS}    ${n}
           IF    ${blocked}
                 CONTINUE
           END
           ${skip}=                             Set Variable          ${FALSE}
           FOR    ${s}    IN    @{suffixes}
                  ${ends}=                      Run Keyword And Return Status               Should End With    ${n}     ${s}
                  IF    ${ends}
                        ${skip}=                Set Variable                                ${TRUE}
                        Exit For Loop
                  END
           END
           IF    ${skip}
                 CONTINUE
           END
           Append To List                       ${keep}                 ${n}
    END
    RETURN                                      ${keep}

Get Skip Reason
    [Documentation]                             Classify skip reason from sf output. Prefers sf JSON "name"/"message" if present.
    [Arguments]                                 ${text}
    ${status}    ${data}=                       Run Keyword And Ignore Error                Safe Parse Sf Json                  ${text}
    IF    '${status}' == 'PASS'
           ${has_name}=                         Run Keyword And Return Status               Dictionary Should Contain Key       ${data}     name
        IF    ${has_name}
              ${ename}=                         Get From Dictionary                         ${data}    name
              ${has_msg}=                       Run Keyword And Return Status               Dictionary Should Contain Key       ${data}     message
              ${emsg}=                          Set Variable                                ${EMPTY}
              IF    ${has_msg}
                    ${emsg}=                    Get From Dictionary                         ${data}    message
              END
              ${has_count_not_supported}=       Run Keyword And Return Status               Should Contain                      ${emsg}     Count operation not supported
              IF    ${has_count_not_supported}
                    RETURN    COUNT_NOT_SUPPORTED
              END
              ${has_stat_required}=             Run Keyword And Return Status               Should Contain                      ${emsg}     Where clauses should contain StatType
              IF    ${has_stat_required}
                    RETURN    REQUIRES_WHERE_StatType
              END
              RETURN    ${ename}
        END
    END
    ${r1}=    Run Keyword And Return Status     Should Contain                              ${text}    INVALID_TYPE_FOR_OPERATION
    IF    ${r1}    RETURN                       INVALID_TYPE_FOR_OPERATION
    ${r2}=    Run Keyword And Return Status     Should Contain                              ${text}    BIG_OBJECT_UNSUPPORTED_OPERATION
    IF    ${r2}    RETURN                       BIG_OBJECT_UNSUPPORTED_OPERATION
    ${r3}=    Run Keyword And Return Status     Should Contain                              ${text}    MALFORMED_QUERY
    IF    ${r3}    RETURN                       MALFORMED_QUERY
    ${r4}=    Run Keyword And Return Status     Should Contain                              ${text}    INVALID_TYPE
    IF    ${r4}    RETURN                       INVALID_TYPE
    ${r5}=    Run Keyword And Return Status     Should Contain                              ${text}    INVALID_SESSION_ID
    IF    ${r5}    RETURN                       INVALID_SESSION_ID
    ${r6}=    Run Keyword And Return Status     Should Contain                              ${text}    INSUFFICIENT_ACCESS
    IF    ${r6}    RETURN                       INSUFFICIENT_ACCESS
    ${r7}=    Run Keyword And Return Status     Should Contain                              ${text}    REQUEST_LIMIT_EXCEEDED
    IF    ${r7}    RETURN                       REQUEST_LIMIT_EXCEEDED
    RETURN                                      OTHER_ERROR


Get Max Timeout For Object
    [Documentation]                             Special-case timeout for known slow objects.
    [Arguments]                                 ${object_name}
    ${is_slow}=                                 Run Keyword And Return Status               List Should Contain Value    ${SLOW_OBJECTS}    ${object_name}
    IF    ${is_slow}
          RETURN                                ${CONNECTEDAPP_TIMEOUT}
    END
    RETURN                                      ${MAX_QUERY_TIMEOUT_SECONDS}

Get Record Count Safe
    [Documentation]                             Execute COUNT() query with timeout protection and clean parsing
    [Arguments]                                 ${object_name}                              ${tooling}=${FALSE}
    ${skip_count_unsupported}=                  Run Keyword And Return Status               List Should Contain Value    ${COUNT_NOT_SUPPORTED_OBJECTS}    ${object_name}
    IF    ${skip_count_unsupported}
          RETURN    ${None}                     COUNT_NOT_SUPPORTED    0.0
    END
    ${skip_requires_where}=                     Run Keyword And Return Status               List Should Contain Value    ${REQUIRES_WHERE_OBJECTS}    ${object_name}
    IF    ${skip_requires_where}
          RETURN    ${None}                     REQUIRES_WHERE_StatType    0.0
    END
    ${query}=                                   Set Variable                                SELECT COUNT() FROM ${object_name}
    @{args}=                                    Create List
    ...    data
    ...    query
    ...    --query
    ...    ${query}
    Run Keyword If    ${tooling}                Append To List                              ${args}    --use-tooling-api
    Append To List    ${args}
    ...    --target-org
    ...    ${ORG_ALIAS}
    ...    --json
    ${start_epoch}=                             Get Current Date                            result_format=epoch
    ${p}=                                       Start Process
    ...    ${SF_CLI}
    ...    @{args}
    ...    stdout=PIPE
    ...    stderr=PIPE
    ${max_timeout}=                             Get Max Timeout For Object                  ${object_name}
    ${poll}=                                    Convert To Number                           ${POLL_INTERVAL_SECONDS}
    WHILE    True
        ${result}=                              Wait For Process                            ${p}    timeout=${poll}     on_timeout=continue
        IF    '${result}' != '${None}'
            BREAK
        END
        ${now}=                                 Get Current Date                            result_format=epoch
        ${elapsed}=                             Evaluate                                    ${now} - ${start_epoch}
        IF    ${elapsed} >= ${max_timeout}
              Terminate Process    ${p}    kill=${TRUE}
              RETURN    ${None}    TIMEOUT    ${elapsed}
        END
    END
    ${end_epoch}=                               Get Current Date                            result_format=epoch
    ${dur}=                                     Evaluate                                    round(float(${end_epoch}) - float(${start_epoch}), 2)
    ${rc}=                                      Set Variable                                ${result.rc}
    ${out}=                                     Set Variable                                ${result.stdout}
    ${err}=                                     Set Variable                                ${result.stderr}
    IF    ${rc} != 0
        ${text}=                                Catenate                                    SEPARATOR=\n    ${out}      ${err}
        ${reason}=                              Get Skip Reason                             ${text}
        RETURN    ${None}    ${reason}    ${dur}
    END
    ${ok}    ${data}=                           Run Keyword And Ignore Error                Safe Parse Sf Json          ${out}
    IF    '${ok}' != 'PASS'
        RETURN    ${None}                       INVALID_JSON_OUTPUT                         ${dur}
    END
    ${has_result}=                              Run Keyword And Return Status               Dictionary Should Contain Key       ${data}     result
    IF    not ${has_result}
        RETURN    ${None}                       INVALID_JSON_STRUCTURE                      ${dur}
    END
    ${result_dict}=                             Get From Dictionary                         ${data}                     result
    ${count}=                                   Get From Dictionary                         ${result_dict}              totalSize
    RETURN    ${count}    OK    ${dur}


Get Tooling Object Names
    [Documentation]                             Returns filtered Tooling API sObject names using /tooling/sobjects.
    ...                                         Keeps only queryable objects and removes noisy suffix patterns.
    ${resp}=                                    Run Sf Api Request Rest Json                /services/data/v${API_VERSION}/tooling/sobjects/
    ${has_key}=                                 Run Keyword And Return Status               Dictionary Should Contain Key    ${resp}    sobjects
    IF    not ${has_key}
          Log To Console                        Tooling discovery response missing "sobjects"; falling back.
          RETURN    @{TOOLING_OBJECTS}
    END
    ${sobjects}=                                Get From Dictionary                         ${resp}    sobjects
    @{names}=                                   Create List
    FOR    ${obj}    IN    @{sobjects}
           ${has_name}=                         Run Keyword And Return Status               Dictionary Should Contain Key    ${obj}    name
           ${has_queryable}=                    Run Keyword And Return Status               Dictionary Should Contain Key    ${obj}    queryable
        IF    not ${has_name}
              CONTINUE
        END
        IF    not ${has_queryable}
              CONTINUE
        END
        ${name}=                                Get From Dictionary                         ${obj}                      name
        ${queryable}=                           Get From Dictionary                         ${obj}                      queryable
        IF    not ${queryable}
              CONTINUE
        END
        Append To List                          ${names}                                    ${name}
    END
    ${count}=                                   Get Length                                  ${names}
    IF    ${count} == 0
          Log To Console                        Tooling filter produced 0 objects; falling back to static list.
          RETURN                                @{TOOLING_OBJECTS}
    END
    RETURN                                      ${names}

Log Summary All Objects
    [Documentation]                             Print all data objects (Object: Count).
    [Arguments]                                 ${data_dict}
    Log To Console                              \nAll data objects (Object: Count):
    ${keys}=                                    Get Dictionary Keys                         ${data_dict}
    FOR    ${k}    IN    @{keys}
        Sort List        ${keys}
        ${v}=                                   Collections.Get From Dictionary             ${data_dict}    ${k}
        Log To Console                          ${k}: ${v}
    END

Log Skipped Summary
    [Documentation]                             Print skipped objects with reasons.
    [Arguments]                                 ${skipped_reasons}
    Log To Console                              \nSkipped objects:
    ${count}=                                   Get Length                                  ${skipped_reasons}
    IF    ${count} == 0
          Log To Console                        (none)
          RETURN
    END
    ${keys}=                                    Get Dictionary Keys                         ${skipped_reasons}
    FOR    ${k}    IN    @{keys}
        ${v}=                                   Collections.Get From Dictionary             ${skipped_reasons}    ${k}
        Log To Console                          ${k}: ${v}
    END

Generate Output File Name
    [Arguments]                                 ${output_directory}
    ${timestamp}=                               Get Time
    ${timestamp}=                               Replace String                              ${timestamp}    :           -
    ${timestamp}=                               Replace String                              ${timestamp}    ${SPACE}    -
    ${output_file}=                             Set Variable                                ${output_directory}${/}${OUTPUT_FILENAME}_${timestamp}.xlsx
    RETURN                                      ${output_file}

Get All Object Record Counts
    [Documentation]                             Main flow: list -> filter -> count -> save JSON (+ durations).
    Check Prerequisites
    ${output_directory}=                        Init Output Directory
    ${output_directory}=                        Normalize Path                              ${output_directory}
    Set Test Variable                           ${output_directory}
    ${Json_directory}=                          Init Json Directory
    ${Json_directory}=                          Normalize Path                              ${Json_directory}
    Set Test Variable                           ${Json_directory}
    ${output_file}=                             Generate Output File Name                   ${output_directory}
    Log To Console                              Starting for org: ${ORG_ALIAS}
    Log To Console                              Output: ${output_file}
    ${list_json}=                               Run Sf Json    sobject    list
    @{all_names}=                               Get Object Names From List                  ${list_json}
    ${raw_count}=                               Get Length                                  ${all_names}
    Log To Console                              Raw objects found: ${raw_count}
    @{countable}=                               Filter Countable Objects                    @{all_names}
    ${filtered}=                                Get Length                                  ${countable}
    Log To Console                              After filter: ${filtered}
    @{limited}=                                 Set Variable                                @{countable}
    ${total}=                                   Get Length                                  ${limited}
    Log To Console                              objects to process: ${total}
    &{data_results}=                            Create Dictionary
    &{tooling_results}=                         Create Dictionary
    &{skipped_reasons}=                         Create Dictionary
    &{durations_seconds}=                       Create Dictionary
    FOR    ${index}    ${obj}    IN ENUMERATE    @{limited}    start=1
           Log To Console                       [Standard]-[${index}/${total}] Counting: ${obj}
           ${count}    ${reason}     ${dur}=    Get Record Count Safe                       ${obj}    tooling=${FALSE}
           Set To Dictionary                    ${durations_seconds}                        ${obj}=${dur}
           IF    '${reason}' == 'OK'
                  Set To Dictionary             ${data_results}                             ${obj}=${count}
                  Log To Console                [Standard]-[${index}/${total}] ${obj}: ${count} (t=${dur}s)
           ELSE
                  Set To Dictionary             ${skipped_reasons}                          ${obj}=${reason}
                  Log To Console                [Standard]-[${index}/${total}] ${obj}: SKIPPED (${reason}) (t=${dur}s)
           END
           Sleep                                ${DELAY_SECONDS}
    END
    IF    ${INCLUDE_TOOLING}
          Log To Console                        \nQuerying Tooling API objects...
          IF    ${DISCOVER_TOOLING_OBJECTS}
                Log To Console                  Discovering tooling objects dynamically...
                @{tooling_list}=                Get Tooling Object Names
          ELSE
                @{tooling_list}=                Set Variable                                @{TOOLING_OBJECTS}
          END
          @{tooling_unique}=                    Create List
          FOR    ${tobj}    IN    @{tooling_list}
                 ${already_in_data}=            Run Keyword And Return Status               List Should Contain Value    ${limited}    ${tobj}
                 IF    not ${already_in_data}
                       Append To List           ${tooling_unique}                           ${tobj}
                 END
          END
          @{tooling_list}=                      Set Variable                                @{tooling_unique}
          ${tooling_total}=                     Get Length                                  ${tooling_list}
          Log To Console                        Tooling objects to process : ${tooling_total}
          FOR    ${index}    ${tobj}    IN ENUMERATE    @{tooling_list}    start=1
                 Log To Console                 [Tooling]-[${index}/${tooling_total}] Counting: ${tobj}
                 ${tcount}    ${treason}        ${tdur}=    Get Record Count Safe           ${tobj}    tooling=${TRUE}
                 Set To Dictionary              ${durations_seconds}                        TOOLING::${tobj}=${tdur}
                 IF    '${treason}' == 'OK'
                        Set To Dictionary       ${tooling_results}                          ${tobj}=${tcount}
                        Log To Console          [Tooling]-[${index}/${tooling_total}] ${tobj}: ${tcount} (t=${tdur}s)
                 ELSE
                        Set To Dictionary       ${skipped_reasons}                          ${tobj}=[TOOLING] ${treason}
                        Log To Console          [Tooling]-[${index}/${tooling_total}] ${tobj}: SKIPPED (${treason}) (t=${tdur}s)
                 END
          END
    END
    ${success_count}=                           Get Length                                  ${data_results}
    ${tooling_success_count}=                   Get Length                                  ${tooling_results}
    ${skip_count}=                              Get Length                                  ${skipped_reasons}
    ${total_processed}=                         Evaluate                                    ${success_count} + ${tooling_success_count} + ${skip_count}
    Log To Console                              \n===== SUMMARY =====
    Log To Console                              Success(Data): ${success_count}
    Log To Console                              Success(Tooling): ${tooling_success_count}
    Log To Console                              Skipped: ${skip_count}
    Log To Console                              Total Processed: ${total_processed}
    Log To Console                              =====================
    Save Results To Excel
    ...    ${output_file}
    ...    ${data_results}
    ...    ${tooling_results}
    ...    ${skipped_reasons}
    ...    ${durations_seconds}
    Log To Console                              \nDone! Results saved to: ${output_file}
    Log Skipped Summary                         ${skipped_reasons}
    Log Summary All Objects                     ${data_results}

Generate Run Id
    ${timestamp}=                               Get Time
    ${timestamp}=                               Replace String    ${timestamp}    :    -
    ${timestamp}=                               Replace String    ${timestamp}    ${SPACE}    -
    RETURN                                      ${timestamp}

Save Results To Excel
    [Arguments]                                 ${output_file}                              ${data_results}                             ${tooling_results}           ${skipped_reasons}    ${durations_seconds}
    ${run_id}=                                  Generate Run Id
    ${data_file}=                               Set Variable                                ${Json_directory}${/}data_${run_id}.json
    ${tooling_file}=                            Set Variable                                ${Json_directory}${/}tooling_${run_id}.json
    ${skipped_file}=                            Set Variable                                ${Json_directory}${/}skipped_${run_id}.json
    ${durations_file}=                          Set Variable                                ${Json_directory}${/}durations_${run_id}.json
    ${data_json}=                               Evaluate                                    json.dumps($data_results)                   modules=json
    ${tooling_json}=                            Evaluate                                    json.dumps($tooling_results)                modules=json
    ${skipped_json}=                            Evaluate                                    json.dumps($skipped_reasons)                modules=json
    ${durations_json}=                          Evaluate                                    json.dumps($durations_seconds)              modules=json
    Create File                                 ${data_file}                                ${data_json}
    Create File                                 ${tooling_file}                             ${tooling_json}
    Create File                                 ${skipped_file}                             ${skipped_json}
    Create File                                 ${durations_file}                           ${durations_json}
    ${result}=    Run Process
    ...    ${PYTHON}
    ...     src${/}robot${/}libraries${/}ExcelWriter.py
    ...    ${data_file}
    ...    ${tooling_file}
    ...    ${skipped_file}
    ...    ${durations_file}
    ...    ${output_file}
    ...    stdout=PIPE
    ...    stderr=PIPE
    Log To Console                              ${result.stdout}
    Log To Console                              ${result.stderr}
    Should Be Equal As Integers                 ${result.rc}        0                       Excel generation failed:\n${result.stdout}\n${result.stderr}

Cleanup Runtime Artifacts
    [Documentation]                        Cleans Pabot temp files, Excel handles, and process artifacts from project root.
    ${items}=                              List Directory                   ${EXECDIR}
    FOR    ${item}    IN    @{items}
           ${full_path}=                   Set Variable                     ${EXECDIR}${/}${item}
           ${is_uuid}=                     Evaluate                         len($item) == 32 and all(c in "0123456789abcdef" for c in $item)
           ${is_known_temp}=               Evaluate                         $item in $TEMP_FILES
           IF    ${is_uuid} or ${is_known_temp}
              ${is_file}=                  Run Keyword And Return Status    File Should Exist                           ${full_path}
            IF    ${is_file}
                Log    Removing temp file: ${item}
                Remove File    ${full_path}
            END
        END
    END

Cleanup Suite
    Cleanup Runtime Artifacts

Init Output Directory
    [Documentation]                        Creates a unique, isolated output folder for the current test case/batch. This folder stores all generated files.
    ...                                    for that specific run, ensuring traceability and no collisions in parallel execution.
    ${uuid}=                               Evaluate                         __import__('uuid').uuid4().hex
    ${run_id}=                             Generate Run Id
    ${safe_test_name}=                     Catenate                         SEPARATOR=                   ${RUN NAME}        ${run_id}
    ${output_directory}=                   Set Variable                     ${OUTPUT_DIR}${/}${safe_test_name}_${uuid}
    Create Directory                       ${output_directory}
    Directory Should Exist                 ${output_directory}
    RETURN                                 ${output_directory}

Init Json Directory
    [Documentation]                        Creates a unique, isolated Jason folder for the current test case/batch. This folder stores all generated jason files.
    ...                                    for that specific run, ensuring traceability and no collisions in parallel execution.
    ${Json_directory}=                     Set Variable                     ${output_directory}${/}Json_Files
    Create Directory                       ${Json_directory}
    Directory Should Exist                 ${Json_directory}
    RETURN                                 ${Json_directory}