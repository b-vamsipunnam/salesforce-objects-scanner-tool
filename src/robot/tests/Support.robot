*** Settings ***
Documentation                       Retrieve record counts for Salesforce objects using Salesforce CLI (sf).
...                                 Filters noisy objects, limits runtime, uses timeout protection (polling).
...                                 Enhancements:
...                                 - Parses sf JSON error payload for better skip reasons
...                                 - Logs per-object duration (seconds)
...                                 - Adds early-skip lists for known "count not supported" objects
Library                             OperatingSystem
Library                             Collections
Library                             BuiltIn
Library                             json
Library                             Process
Library                             DateTime

*** Variables ***
${ORG_ALIAS}                        DeveloperOrg

# Windows execution
${SF_CMD}                           cmd.exe
${SF_CLI}                           sf

${OUTPUT_DIR}                       ${CURDIR}${/}results
${OUTPUT_FILENAME}                  salesforce_record_counts.json

# Runtime controls
${DELAY_SECONDS}                    0.1

# Polling timeout controls (dynamic wait with max cap)
${MAX_QUERY_TIMEOUT_SECONDS}        120
${POLL_INTERVAL_SECONDS}            1.0
${CONNECTEDAPP_TIMEOUT}             180

# Treat these as known slow / special timeout
@{SLOW_OBJECTS}                     ConnectedApplication

# Tooling controls
${INCLUDE_TOOLING}                  ${TRUE}
${DISCOVER_TOOLING_OBJECTS}         ${TRUE}
${API_VERSION}                      65.0

@{TOOLING_OBJECTS}                  ApexClass    ApexTrigger    CustomField    ValidationRule
...                                 ApexPage      ApexComponent  CustomObject   Profile
...                                 PermissionSet  EntityDefinition

# Known "not countable" / restricted objects (pre-filter)
@{NON_COUNTABLE_OBJECTS}            AggregateResult    ApiEventStream    AsyncOperationStatus
...                                 AttachedContentDocument    CombinedAttachment
...                                 BulkApiResultEventStore
...                                 ApexTypeImplementor    AppTabMember    ColorDefinition
...                                 ContentDocumentLink
...                                 ContentFolderItem    ContentFolderMember

# Known objects where COUNT() is not supported (avoid wasting time)
@{COUNT_NOT_SUPPORTED_OBJECTS}      DataEncryptionKey

# Known objects that require additional WHERE clause (avoid wasting time; classify clearly)
@{REQUIRES_WHERE_OBJECTS}           DataStatistics

*** Keywords ***
Check Prerequisites
    [Documentation]                     Ensure sf is installed and org alias is authenticated.
    Create Directory                    ${OUTPUT_DIR}
    ${rc}    ${out}=                    Run And Return Rc And Output        ${SF_CLI} --version
    ${rc_int}=                          Convert To Integer                  ${rc}
    Should Be Equal As Integers         ${rc_int}     0                     Salesforce CLI (sf) not found or not in PATH.\n${out}
    ${rc2}    ${out2}=                  Run And Return Rc And Output        ${SF_CLI} org display --target-org ${ORG_ALIAS} --json
    ${rc_int2}=                         Convert To Integer                  ${rc2}
    Should Be Equal As Integers         ${rc_int2}    0                     Org alias not found or not authenticated: ${ORG_ALIAS}\n${out2}


Run Sf Json
    [Documentation]                     Run an sf command and return parsed JSON dict.
    [Arguments]                         ${command}
    ${rc}    ${out}=                    Run And Return Rc And Output        ${SF_CLI} ${command} --target-org ${ORG_ALIAS} --json
    ${rc_int}=                          Convert To Integer                  ${rc}
    Should Be Equal As Integers         ${rc_int}     0                     Command failed: sf ${command}\n${out}
    ${data}=                            Evaluate    json.loads(r'''${out}''')    modules=json
    RETURN                              ${data}


Run Sf Api Request Rest Json
    [Documentation]                     Call Salesforce REST endpoint via "sf api request rest" and return parsed JSON dict.
    [Arguments]                         ${relative_url}
    ${rc}    ${out}=                    Run And Return Rc And Output        ${SF_CLI} api request rest ${relative_url} --target-org ${ORG_ALIAS}
    ${rc_int}=                          Convert To Integer                  ${rc}
    IF    ${rc_int} != 0
        Log To Console                  sf api request rest failed (rc=${rc_int}): ${out}
        RETURN                          ${None}
    END
    # sf may print warnings before JSON. Extract JSON starting at first '{' or '['.
    ${start}=                           Evaluate    min([i for i in [r'''${out}'''.find('{'), r'''${out}'''.find('[')] if i != -1], default=-1)
    IF    ${start} == -1
        Log To Console                  Could not find JSON payload in sf output:\n${out}
        RETURN                          ${None}
    END
    ${json_text}=                       Evaluate    r'''${out}'''[${start}:]    modules=None
    ${data}=                            Evaluate    json.loads(r'''${json_text}''')    modules=json
    RETURN                              ${data}


Get Object Names From List
    [Documentation]                     sf sobject list --json => {"result": ["Account", ...]}.
    [Arguments]                         ${list_json}
    @{names}=                           Collections.Get From Dictionary     ${list_json}    result
    RETURN                              ${names}


Filter Countable Objects
    [Documentation]                     Remove noisy/high-volume platform objects + known restricted objects.
    [Arguments]                         @{names}
    @{suffixes}=                        Create List
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

    @{keep}=                            Create List
    FOR    ${n}    IN    @{names}
           ${blocked}=                  Run Keyword And Return Status       List Should Contain Value    ${NON_COUNTABLE_OBJECTS}    ${n}
           IF    ${blocked}
                 CONTINUE
           END
           ${skip}=                     Set Variable                        ${FALSE}
           FOR    ${s}    IN    @{suffixes}
                  ${ends}=              Run Keyword And Return Status       Should End With    ${n}    ${s}
                  IF    ${ends}
                        ${skip}=        Set Variable                        ${TRUE}
                        Exit For Loop
                  END
           END
           IF    ${skip}
                 CONTINUE
           END
           Append To List               ${keep}                             ${n}
    END
    RETURN                              ${keep}

Get Skip Reason
    [Documentation]                     Classify skip reason from sf output.
    ...                                 Prefers sf JSON "name"/"message" if present.
    [Arguments]                         ${text}
    # Try to parse a JSON object from text (sf prints JSON to stdout/stderr)
    ${start}=                           Evaluate    min([i for i in [r'''${text}'''.find('{'), r'''${text}'''.find('[')] if i != -1], default=-1)
    IF    ${start} != -1
          ${json_text}=                 Evaluate    r'''${text}'''[${start}:]    modules=None
          ${ok}=                        Run Keyword And Return Status       Evaluate    json.loads(r'''${json_text}''')    modules=json
        IF    ${ok}
              ${data}=                  Evaluate    json.loads(r'''${json_text}''')    modules=json
              ${has_name}=              Run Keyword And Return Status       Dictionary Should Contain Key    ${data}    name
            IF    ${has_name}
                  ${ename}=             Collections.Get From Dictionary     ${data}    name
                  ${has_msg}=           Run Keyword And Return Status       Dictionary Should Contain Key    ${data}    message
                  ${emsg}=              Set Variable                        ${EMPTY}
                  IF    ${has_msg}
                        ${emsg}=        Collections.Get From Dictionary     ${data}    message
                  END
                  # Normalize the patterns you've observed
                  ${has_count_not_supported}=    Run Keyword And Return Status    Should Contain    ${emsg}    Count operation not supported
                  IF    ${has_count_not_supported}
                        RETURN          COUNT_NOT_SUPPORTED
                  END
                  ${has_stat_required}=    Run Keyword And Return Status    Should Contain    ${emsg}    Where clauses should contain StatType
                  IF    ${has_stat_required}
                        RETURN          REQUIRES_WHERE_StatType
                  END
                  RETURN                ${ename}
            END
        END
    END
    # Fallback: substring checks (keep your original logic)
    ${r1}=                              Run Keyword And Return Status       Should Contain    ${text}    INVALID_TYPE_FOR_OPERATION
    IF    ${r1}                         RETURN    INVALID_TYPE_FOR_OPERATION
    ${r2}=                              Run Keyword And Return Status       Should Contain    ${text}    BIG_OBJECT_UNSUPPORTED_OPERATION
    IF    ${r2}                         RETURN    BIG_OBJECT_UNSUPPORTED_OPERATION
    ${r3}=                              Run Keyword And Return Status       Should Contain    ${text}    MALFORMED_QUERY
    IF    ${r3}                         RETURN    MALFORMED_QUERY
    ${r4}=                              Run Keyword And Return Status       Should Contain    ${text}    INVALID_TYPE
    IF    ${r4}                         RETURN    INVALID_TYPE
    RETURN                              OTHER_ERROR


Get Max Timeout For Object
    [Documentation]                     Special-case timeout for known slow objects.
    [Arguments]                         ${object_name}
    ${is_slow}=                         Run Keyword And Return Status       List Should Contain Value    ${SLOW_OBJECTS}    ${object_name}
    IF    ${is_slow}
          RETURN                        ${CONNECTEDAPP_TIMEOUT}
    END
    RETURN                              ${MAX_QUERY_TIMEOUT_SECONDS}

Get Record Count Safe
    [Documentation]                     Runs SELECT COUNT() with polling.
    ...                                 Returns: <count or ${None}>    <reason>    <duration_seconds>
    [Arguments]                         ${object_name}                      ${tooling}=${FALSE}
    # Early-skip known cases to save runtime
    ${skip_count_unsupported}=          Run Keyword And Return Status       List Should Contain Value    ${COUNT_NOT_SUPPORTED_OBJECTS}    ${object_name}
    IF    ${skip_count_unsupported}
          RETURN                        ${None}    COUNT_NOT_SUPPORTED    0.0
    END
    ${skip_requires_where}=             Run Keyword And Return Status       List Should Contain Value    ${REQUIRES_WHERE_OBJECTS}    ${object_name}
    IF    ${skip_requires_where}
          RETURN                        ${None}    REQUIRES_WHERE_StatType    0.0
    END
    ${query}=                           Set Variable                        SELECT COUNT() FROM ${object_name}
    @{args}=                            Create List
    ...    /c
    ...    ${SF_CLI}
    ...    data
    ...    query
    IF    ${tooling}
          Append To List                ${args}                             --use-tooling-api
    END
    Append To List                      ${args}                             --query
    Append To List                      ${args}                             ${query}
    Append To List                      ${args}                             --target-org
    Append To List                      ${args}                             ${ORG_ALIAS}
    Append To List                      ${args}                             --json
    ${poll}=                            Convert To Number                   ${POLL_INTERVAL_SECONDS}
    ${max_timeout}=                     Get Max Timeout For Object          ${object_name}
    ${start_epoch}=                     Get Current Date                    result_format=epoch
    ${p}=                               Start Process                       ${SF_CMD}    @{args}    shell=${FALSE}    stdout=PIPE    stderr=PIPE
    ${elapsed}=                         Set Variable    0.0
    WHILE    ${elapsed} < ${max_timeout}
             ${res}=                    Wait For Process                    ${p}    timeout=${poll}    on_timeout=continue
        IF    '${res}' != '${None}'
               ${end_epoch}=            Get Current Date                    result_format=epoch
               ${dur}=                  Evaluate                            float(${end_epoch}) - float(${start_epoch})
               ${rc}=                   Set Variable                        ${res.rc}
               ${out}=                  Set Variable                        ${res.stdout}
               ${err}=                  Set Variable                        ${res.stderr}
               IF    ${rc} != 0
                     ${text}=           Catenate                            SEPARATOR=\n    ${out}    ${err}
                     ${reason}=         Get Skip Reason                     ${text}
                     RETURN             ${None}                             ${reason}    ${dur}
               END
               # Parse only the first JSON object/array from stdout
               ${payload}=              Evaluate                            r'''${out}'''.lstrip()    modules=None
               ${end}=                  Evaluate                            __import__("json").JSONDecoder().raw_decode(r'''${payload}''')[1]    modules=None
               ${first}=                Evaluate                            r'''${payload}'''[:${end}]    modules=None
               ${data}=                 Evaluate                            json.loads(r'''${first}''')    modules=json
               ${result}=               Collections.Get From Dictionary     ${data}      result
               ${count}=                Collections.Get From Dictionary     ${result}    totalSize
               RETURN                   ${count}    OK    ${dur}
        END
        ${elapsed}=                     Evaluate                            ${elapsed} + ${poll}
    END
    Terminate Process                   ${p}        kill=${TRUE}
    ${end_epoch}=                       Get Current Date                    result_format=epoch
    ${dur}=                             Evaluate                            float(${end_epoch}) - float(${start_epoch})
    RETURN                              ${None}     TIMEOUT    ${dur}

Get Tooling Object Names
    [Documentation]                     Returns filtered Tooling API sObject names using /tooling/sobjects.
    ...                                 Keeps only queryable objects and removes noisy suffix patterns.
    ${resp}=                            Run Sf Api Request Rest Json    /services/data/v${API_VERSION}/tooling/sobjects/
    ${is_none}=                         Run Keyword And Return Status    Should Be Equal    ${resp}    ${None}
    IF    ${is_none}
          Log To Console                Tooling discovery failed; falling back to static TOOLING_OBJECTS list.
          RETURN                        @{TOOLING_OBJECTS}
    END
    ${has_key}=                         Run Keyword And Return Status    Dictionary Should Contain Key    ${resp}    sobjects
    IF    not ${has_key}
          Log To Console                Tooling discovery response missing "sobjects"; falling back.
          RETURN                        @{TOOLING_OBJECTS}
    END
    ${sobjects}=                        Collections.Get From Dictionary    ${resp}    sobjects
    @{skip_suffixes}=                   Create List
    ...    Settings
    ...    Member
    ...    Members
    ...    Spec
    ...    Version
    ...    Versions
    ...    Info
    ...    Layout
    ...    Layouts
    ...    Mapping
    ...    Mappings
    ...    Definition
    ...    Definitions

    @{names}=                           Create List
    FOR    ${obj}    IN    @{sobjects}
        ${queryable}=                   Collections.Get From Dictionary    ${obj}    queryable
        IF    not ${queryable}
            CONTINUE
        END
        ${name}=                        Collections.Get From Dictionary    ${obj}    name
        ${skip}=                        Set Variable                       ${FALSE}
        FOR    ${s}    IN    @{skip_suffixes}
               ${ends}=                 Run Keyword And Return Status    Should End With    ${name}    ${s}
            IF    ${ends}
                  ${skip}=              Set Variable    ${TRUE}
                  Exit For Loop
            END
        END
        IF    ${skip}
              CONTINUE
        END
        Append To List                  ${names}      ${name}
    END
    ${count}=                           Get Length    ${names}
    IF    ${count} == 0
          Log To Console                Tooling filter produced 0 objects; falling back to static list.
          RETURN                        @{TOOLING_OBJECTS}
    END
    RETURN    ${names}

Log Summary All Objects
    [Documentation]                     Print all data objects (Object: Count).
    [Arguments]                         ${data_dict}
    Log To Console                      \nAll data objects (Object: Count):
    ${keys}=                            Get Dictionary Keys    ${data_dict}
    FOR    ${k}    IN    @{keys}
        ${v}=                           Collections.Get From Dictionary     ${data_dict}    ${k}
        Log To Console                  ${k}: ${v}
    END


Log Skipped Summary
    [Documentation]                     Print skipped objects with reasons.
    [Arguments]                         ${skipped_reasons}
    Log To Console                      \nSkipped objects:
    ${count}=                           Get Length                         ${skipped_reasons}
    IF    ${count} == 0
          Log To Console                (none)
          RETURN
    END
    ${keys}=                            Get Dictionary Keys                ${skipped_reasons}
    FOR    ${k}    IN    @{keys}
        ${v}=                           Collections.Get From Dictionary    ${skipped_reasons}    ${k}
        Log To Console                  ${k}: ${v}
    END


Get All Object Record Counts
    [Documentation]                     Main flow: list -> filter -> count -> save JSON (+ durations).
    Check Prerequisites
    ${output_file}=                     Set Variable                       ${OUTPUT_DIR}${/}${OUTPUT_FILENAME}
    Log To Console                      Starting for org: ${ORG_ALIAS}
    Log To Console                      Output: ${output_file}
    ${list_json}=                       Run Sf Json    sobject list
    @{all_names}=                       Get Object Names From List         ${list_json}
    ${raw_count}=                       Get Length                         ${all_names}
    Log To Console                      Raw objects found: ${raw_count}
    @{countable}=                       Filter Countable Objects           @{all_names}
    ${filtered}=                        Get Length                         ${countable}
    Log To Console                      After filter: ${filtered}
    @{limited}=                         Set Variable                       @{countable}
    ${total}=                           Get Length                         ${limited}
    Log To Console                      objects to process: ${total}
    &{data_results}=                    Create Dictionary
    &{tooling_results}=                 Create Dictionary
    &{skipped_reasons}=                 Create Dictionary
    &{durations_seconds}=               Create Dictionary

    FOR    ${index}    ${obj}    IN ENUMERATE    @{limited}    start=1
           Log To Console               [${index}/${total}] Counting: ${obj}
           ${count}    ${reason}     ${dur}=    Get Record Count Safe    ${obj}    tooling=${FALSE}
           # Store duration always (even for skipped)
           Set To Dictionary            ${durations_seconds}    ${obj}=${dur}
           IF    '${reason}' == 'OK'
                  Set To Dictionary     ${data_results}    ${obj}=${count}
                  Log To Console        [Standard]-[${index}/${total}] ${obj}: ${count} (t=${dur}s)
           ELSE
                  Set To Dictionary     ${skipped_reasons}    ${obj}=${reason}
                  Log To Console        [Standard]-[${index}/${total}] ${obj}: SKIPPED (${reason}) (t=${dur}s)
           END
           Sleep                        ${DELAY_SECONDS}
    END

    IF    ${INCLUDE_TOOLING}
          Log To Console                  \nQuerying Tooling API objects...
          IF    ${DISCOVER_TOOLING_OBJECTS}
                Log To Console            Discovering tooling objects dynamically...
                @{tooling_list}=          Get Tooling Object Names
          ELSE
                @{tooling_list}=          Set Variable          @{TOOLING_OBJECTS}
          END
          # Deduplicate tooling objects already processed as data objects
          @{tooling_unique}=              Create List
          FOR    ${tobj}    IN    @{tooling_list}
                 ${already_in_data}=      Run Keyword And Return Status    List Should Contain Value    ${limited}    ${tobj}
                 IF    not ${already_in_data}
                       Append To List     ${tooling_unique}     ${tobj}
                 END
          END
          @{tooling_list}=                Set Variable          @{tooling_unique}
          ${tooling_total}=               Get Length            ${tooling_list}
          Log To Console       Tooling objects to process : ${tooling_total}
          FOR    ${index}    ${tobj}    IN ENUMERATE    @{tooling_list}    start=1
                 Log To Console              [${index}/${tooling_total}] Counting: ${tobj}
                 ${tcount}    ${treason}     ${tdur}=    Get Record Count Safe    ${tobj}    tooling=${TRUE}
                 # Store tooling duration too (prefix key so it won't collide)
                 Set To Dictionary           ${durations_seconds}    TOOLING::${tobj}=${tdur}
                 IF    '${treason}' == 'OK'
                        Set To Dictionary    ${tooling_results}    ${tobj}=${tcount}
                        Log To Console       [Tooling]-[${index}/${tooling_total}] ${tobj}: ${tcount} (t=${tdur}s)
                 ELSE
                        Set To Dictionary    ${skipped_reasons}    ${tobj}=[TOOLING] ${treason}
                        Log To Console       [Tooling]-[${index}/${tooling_total}] ${tobj}: SKIPPED (${treason}) (t=${tdur}s)
                 END
          END
    END
    &{results}=          Create Dictionary
    ...    data_objects=${data_results}
    ...    tooling_objects=${tooling_results}
    ...    skipped_objects=${skipped_reasons}
    ...    durations_seconds=${durations_seconds}

    ${json_string}=      Evaluate            json.dumps($results, indent=2)    modules=json
    Create File          ${output_file}      ${json_string}

    Log To Console                           \nDone! Results saved to: ${output_file}
    Log Skipped Summary                      ${skipped_reasons}
    Log Summary All Objects                  ${data_results}
