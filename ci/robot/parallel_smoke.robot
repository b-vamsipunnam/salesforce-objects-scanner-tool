*** Settings ***
Documentation     CI-safe end-to-end validation of balanced Pabot execution.
Library           Collections
Resource          ../../src/robot/resources/keywords.robot
Suite Teardown    Cleanup Parallel Smoke


*** Variables ***
${PARALLEL_SMOKE_DIR}    ${EXECDIR}${/}output${/}parallel-smoke-ci


*** Test Cases ***
Smoke - Pabot Executes Balanced Object Batches
    [Documentation]    Verify Pabot schedules and consolidates isolated standard and Tooling work items.
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}unsupported-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    @{data_objects}=    Create List    AggregateResult
    @{tooling_objects}=    Create List    DataStatistics
    ${data}    ${tooling}    ${skipped}    ${details}    ${durations}=
    ...    Run Object Queries With Pabot
    ...    ${data_objects}
    ...    ${tooling_objects}
    ...    ${PARALLEL_SMOKE_DIR}
    Should Be Empty    ${data}
    Should Be Empty    ${tooling}
    Dictionary Should Contain Item    ${skipped}    AggregateResult    INVALID_TYPE
    Dictionary Should Contain Item    ${skipped}    TOOLING::DataStatistics    INVALID_TYPE
    Dictionary Should Contain Key    ${durations}    AggregateResult
    Dictionary Should Contain Key    ${durations}    TOOLING::DataStatistics
    Dictionary Should Contain Key    ${details}    AggregateResult

Smoke - Concurrent CLI Results Stay With Their Objects
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}fake-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${PABOT_PROCESSES}    ${2}    scope=TEST
    VAR    ${PABOT_SHARDS_PER_PROCESS}    ${2}    scope=TEST
    @{data_objects}=    Create List    Account    Contact
    @{tooling_objects}=    Create List    ApexClass
    ${data}    ${tooling}    ${skipped}    ${details}    ${durations}=
    ...    Run Object Queries With Pabot
    ...    ${data_objects}
    ...    ${tooling_objects}
    ...    ${PARALLEL_SMOKE_DIR}${/}fake-run
    Dictionary Should Contain Item    ${data}    Account    ${42}
    Dictionary Should Contain Item    ${data}    Contact    ${7}
    Dictionary Should Contain Item    ${tooling}    ApexClass    ${3}
    Should Be Empty    ${skipped}
    Should Be Empty    ${details}
    Length Should Be    ${durations}    3

Smoke - Tooling Discovery Failure Is Operational
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}discovery-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${API_VERSION}    65.0    scope=TEST
    ${objects}    ${reason}=    Get Tooling Object Names
    Should Be Empty    ${objects}
    Should Be Equal    ${reason}    TOOLING_DISCOVERY_FAILED

Smoke - Large Discovery Output Does Not Deadlock
    [Documentation]    Verify file-backed capture handles sf JSON larger than an operating-system pipe.
    ${run_directory}=    Set Variable    ${PARALLEL_SMOKE_DIR}${/}large-discovery
    ${fake_sf}=    Create Fake Sf Launcher    ${run_directory}${/}fake-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${SCAN_OUTPUT_ROOT}    ${run_directory}    scope=TEST
    VAR    ${SF_COMMAND_TIMEOUT_SECONDS}    ${5}    scope=TEST
    ${response}=    Run Sf Json    sobject    list
    ${names}=    Get Object Names From List    ${response}
    Length Should Be    ${names}    10000

Smoke - Large Count Query Output Does Not Deadlock
    [Documentation]    Verify count-query attempts use file-backed stdout and stderr.
    ${run_directory}=    Set Variable    ${PARALLEL_SMOKE_DIR}${/}large-query
    ${fake_sf}=    Create Fake Sf Launcher    ${run_directory}${/}fake-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${SCAN_OUTPUT_ROOT}    ${run_directory}    scope=TEST
    VAR    ${MAX_QUERY_TIMEOUT_SECONDS}    ${5}    scope=TEST
    ${count}    ${reason}    ${duration}    ${details}=    Get Record Count Safe    LargeQueryObject
    Should Be Equal As Integers    ${count}    9
    Should Be Equal    ${reason}    OK
    Should Be Empty    ${details}

Smoke - Unexpected Worker Error Preserves Artifact
    VAR    ${SF_CLI}    ${PARALLEL_SMOKE_DIR}${/}missing-sf    scope=TEST
    VAR    ${POLL_INTERVAL_SECONDS}    access_token=rawWorkerSecret    scope=TEST
    @{data_objects}=    Create List    Account
    @{tooling_objects}=    Create List
    ${data}    ${tooling}    ${skipped}    ${details}    ${durations}=
    ...    Run Object Queries With Pabot
    ...    ${data_objects}
    ...    ${tooling_objects}
    ...    ${PARALLEL_SMOKE_DIR}${/}worker-error-run
    Should Be Empty    ${data}
    Should Be Empty    ${tooling}
    Dictionary Should Contain Item    ${skipped}    Account    CLI_EXECUTION_FAILED
    Dictionary Should Contain Key    ${durations}    Account
    Dictionary Should Contain Key    ${details}    Account
    Dictionary Should Contain Item    ${details}[Account]    name    CLI_EXECUTION_FAILED
    Should Not Be Empty    ${details}[Account][message]

Smoke - Pabot Workers Receive Query Timing Configuration
    [Documentation]    Verify scalar and list settings cross the isolated worker-process boundary.
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}worker-config-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${MAX_QUERY_TIMEOUT_SECONDS}    ${1}    scope=TEST
    VAR    ${CONNECTEDAPP_TIMEOUT}    ${2}    scope=TEST
    VAR    ${POLL_INTERVAL_SECONDS}    ${0.1}    scope=TEST
    VAR    ${SLOW_OBJECTS}    SlowObject    scope=TEST
    @{data_objects}=    Create List    SleepObject    SlowObject
    @{tooling_objects}=    Create List
    ${data}    ${tooling}    ${skipped}    ${details}    ${durations}=
    ...    Run Object Queries With Pabot
    ...    ${data_objects}
    ...    ${tooling_objects}
    ...    ${PARALLEL_SMOKE_DIR}${/}worker-config-run
    Dictionary Should Contain Item    ${data}    SlowObject    ${11}
    Dictionary Should Contain Item    ${skipped}    SleepObject    TIMEOUT
    Should Be Empty    ${tooling}

Smoke - Query Timeout Terminates Process
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}timeout-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${MAX_QUERY_TIMEOUT_SECONDS}    ${1}    scope=TEST
    VAR    ${POLL_INTERVAL_SECONDS}    ${0.1}    scope=TEST
    ${count}    ${reason}    ${duration}    ${details}=    Get Record Count Safe    SleepObject
    Should Be Equal    ${count}    ${None}
    Should Be Equal    ${reason}    TIMEOUT
    Should Be True    ${duration} >= 1
    Dictionary Should Contain Item    ${details}    name    TIMEOUT

Smoke - Transient Salesforce Failure Is Retried And Preserved
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}retry-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${SF_TRANSIENT_RETRIES}    ${1}    scope=TEST
    VAR    ${SF_RETRY_BACKOFF_SECONDS}    ${0.1}    scope=TEST
    ${count}    ${reason}    ${duration}    ${details}=
    ...    Get Record Count Safe    ExternalFailure
    Should Be Equal    ${count}    ${None}
    Should Be Equal    ${reason}    EXTERNAL_OBJECT_EXCEPTION
    Should Be True    ${duration} >= 0.1
    Dictionary Should Contain Item    ${details}    name    EXTERNAL_OBJECT_EXCEPTION
    Dictionary Should Contain Item    ${details}    attempts    ${2}
    Should Contain    ${details}[message]    temporarily unavailable

Smoke - Deterministic External Failure Is Not Retried
    ${fake_sf}=    Create Fake Sf Launcher    ${PARALLEL_SMOKE_DIR}${/}deterministic-cli
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${SF_TRANSIENT_RETRIES}    ${2}    scope=TEST
    VAR    ${SF_RETRY_BACKOFF_SECONDS}    ${0.1}    scope=TEST
    ${count}    ${reason}    ${duration}    ${details}=
    ...    Get Record Count Safe    DeterministicExternalFailure
    Should Be Equal    ${count}    ${None}
    Should Be Equal    ${reason}    EXTERNAL_OBJECT_EXCEPTION
    Dictionary Should Contain Item    ${details}    attempts    ${1}
    Should Contain    ${details}[message]    Cannot access


*** Keywords ***
Create Fake Sf Launcher
    [Documentation]    Create a platform-specific executable wrapper around the deterministic fake sf fixture.
    [Arguments]    ${launcher_directory}
    Create Directory    ${launcher_directory}
    ${python}=    Current Python Executable
    ${fake_script}=    Normalize Path    ${CURDIR}${/}..${/}fakes${/}fake_sf.py
    ${is_windows}=    Evaluate    __import__('os').name == 'nt'
    IF    ${is_windows}
        ${launcher}=    Normalize Path    ${launcher_directory}${/}sf.cmd
        ${content}=    Set Variable    @echo off\r\n"${python}" "${fake_script}" %*\r\n
        Create File    ${launcher}    ${content}
    ELSE
        ${launcher}=    Normalize Path    ${launcher_directory}${/}sf
        ${content}=    Set Variable    \#!/usr/bin/env sh\nexec "${python}" "${fake_script}" "$@"\n
        Create File    ${launcher}    ${content}
        ${launcher_content}=    Get File    ${launcher}
        Should Be True
        ...    $launcher_content.startswith('#!')
        ...    POSIX fake Salesforce launcher must start with a shebang.
        ${chmod}=    Run Process    chmod    +x    ${launcher}
        Should Be Equal As Integers    ${chmod.rc}    0
    END
    RETURN    ${launcher}

Cleanup Parallel Smoke
    [Documentation]    Remove only the runtime artifacts generated by this smoke suite.
    Run Keyword And Ignore Error    Remove Directory    ${PARALLEL_SMOKE_DIR}    recursive=${TRUE}
