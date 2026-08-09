*** Settings ***
Documentation     Public workflow keywords for the Salesforce Objects Scanner.
Library           BuiltIn
Library           Collections
Resource          configuration.resource
Resource          parallel_execution.resource
Resource          reporting.resource
Resource          salesforce.resource


*** Keywords ***
Normalize Scanner Configuration
    [Documentation]    Convert command-line values to strongly typed Robot variables.
    [Arguments]    ${include_value}=${INCLUDE_TOOLING}
    ...    ${fail_value}=${FAIL_ON_OPERATIONAL_ERRORS}
    ...    ${process_value}=${PABOT_PROCESSES}
    ...    ${shard_value}=${PABOT_SHARDS_PER_PROCESS}
    ...    ${query_timeout_value}=${MAX_QUERY_TIMEOUT_SECONDS}
    ...    ${slow_timeout_value}=${CONNECTEDAPP_TIMEOUT}
    ${include_tooling}=    Convert To Boolean    ${include_value}
    ${fail_on_errors}=    Convert To Boolean    ${fail_value}
    ${processes}=    Convert To Integer    ${process_value}
    ${shards_per_process}=    Convert To Integer    ${shard_value}
    ${query_timeout}=    Convert To Integer    ${query_timeout_value}
    ${slow_timeout}=    Convert To Integer    ${slow_timeout_value}
    Should Be True    ${processes} > 0    PABOT_PROCESSES must be greater than zero.
    Should Be True    ${shards_per_process} > 0    PABOT_SHARDS_PER_PROCESS must be greater than zero.
    Should Be True    ${query_timeout} > 0    MAX_QUERY_TIMEOUT_SECONDS must be greater than zero.
    Should Be True    ${slow_timeout} > 0    CONNECTEDAPP_TIMEOUT must be greater than zero.
    VAR    ${INCLUDE_TOOLING}    ${include_tooling}    scope=SUITE
    VAR    ${FAIL_ON_OPERATIONAL_ERRORS}    ${fail_on_errors}    scope=SUITE
    VAR    ${PABOT_PROCESSES}    ${processes}    scope=SUITE
    VAR    ${PABOT_SHARDS_PER_PROCESS}    ${shards_per_process}    scope=SUITE
    VAR    ${MAX_QUERY_TIMEOUT_SECONDS}    ${query_timeout}    scope=SUITE
    VAR    ${CONNECTEDAPP_TIMEOUT}    ${slow_timeout}    scope=SUITE
    RETURN
    ...    ${include_tooling}
    ...    ${fail_on_errors}
    ...    ${processes}
    ...    ${shards_per_process}

Get All Object Record Counts
    [Documentation]    Discover, count, validate, and report Salesforce object records.
    [Arguments]    ${org_alias}
    VAR    ${ORG_ALIAS}    ${org_alias}    scope=SUITE
    Normalize Scanner Configuration
    Validate Org Alias
    Check Prerequisites
    ${output_directory}=    Init Output Directory
    ${json_directory}=    Init Json Directory    ${output_directory}
    ${workbook_path}=    Generate Output File Name    ${output_directory}
    Log To Console    Starting scan for org: ${ORG_ALIAS}
    Log To Console    Output: ${workbook_path}

    ${list_json}=    Run Sf Json    sobject    list
    ${all_names}=    Get Object Names From List    ${list_json}
    ${raw_count}=    Get Length    ${all_names}
    ${data_objects}=    Deduplicate Object Names    ${all_names}
    ${data_total}=    Get Length    ${data_objects}
    Log To Console    Raw objects found: ${raw_count}
    Log To Console    Unique data objects: ${data_total}

    ${tooling_objects}=    Create List
    ${tooling_discovery_reason}=    Set Variable    OK
    IF    $INCLUDE_TOOLING
        Log To Console    Discovering Tooling API objects...
        ${tooling_objects}    ${tooling_discovery_reason}=    Get Tooling Object Names
        ${tooling_objects}=    Deduplicate Object Names    ${tooling_objects}
    END
    ${tooling_total}=    Get Length    ${tooling_objects}
    Log To Console    Tooling objects: ${tooling_total}

    ${data_results}    ${tooling_results}    ${skipped_reasons}    ${durations_seconds}=
    ...    Run Object Queries With Pabot
    ...    ${data_objects}
    ...    ${tooling_objects}
    ...    ${output_directory}
    IF    '${tooling_discovery_reason}' != 'OK'
        Set To Dictionary
        ...    ${skipped_reasons}
        ...    TOOLING::DISCOVERY=${tooling_discovery_reason}
        Set To Dictionary    ${durations_seconds}    TOOLING::DISCOVERY=${0.0}
    END

    Log Scan Summary    ${data_results}    ${tooling_results}    ${skipped_reasons}
    Save Results To Excel
    ...    ${workbook_path}
    ...    ${json_directory}
    ...    ${data_results}
    ...    ${tooling_results}
    ...    ${skipped_reasons}
    ...    ${durations_seconds}
    Log To Console    Done. Results saved to: ${workbook_path}
    Log Skipped Summary    ${skipped_reasons}
    Log Data Summary    ${data_results}
    Validate Scan Quality    ${skipped_reasons}
