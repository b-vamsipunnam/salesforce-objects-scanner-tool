*** Settings ***
Documentation     End-to-end credential containment validation.
Library           Collections
Library           OperatingSystem
Resource          ../../src/robot/resources/keywords.robot


*** Test Cases ***
Fake Salesforce Token Never Reaches Reports
    Exercise Fake Token Failure
    Save Fake Token Failure Reports


*** Keywords ***
Exercise Fake Token Failure
    [Documentation]    Capture a fake token-bearing Salesforce failure through the production boundary.
    ${run_directory}=    Set Variable    ${SCAN_OUTPUT_ROOT}${/}security-scan
    ${fake_sf}=    Create Security Fake Sf Launcher    ${run_directory}${/}fake-cli
    ${python}=    Current Python Executable
    VAR    ${SF_CLI}    ${fake_sf}    scope=TEST
    VAR    ${PYTHON}    ${python}    scope=TEST
    VAR    ${SF_TRANSIENT_RETRIES}    ${0}    scope=TEST
    ${count}    ${reason}    ${duration}    ${details}=    Get Record Count Safe    TokenFailure
    Should Be Equal    ${count}    ${None}
    Should Be Equal    ${reason}    INVALID_SESSION_ID
    VAR    ${SECURITY_REASON}    ${reason}    scope=SUITE
    VAR    ${SECURITY_DURATION}    ${duration}    scope=SUITE
    VAR    ${SECURITY_DETAILS}    ${details}    scope=SUITE

Save Fake Token Failure Reports
    [Documentation]    Persist the sanitized failure through JSON and Excel reporting.
    ${run_directory}=    Set Variable    ${SCAN_OUTPUT_ROOT}${/}security-scan
    ${json_directory}=    Init Json Directory    ${run_directory}
    ${workbook}=    Normalize Path    ${run_directory}${/}security.xlsx
    &{data}=    Create Dictionary
    &{tooling}=    Create Dictionary
    &{skipped}=    Create Dictionary    TokenFailure=${SECURITY_REASON}
    &{skipped_details}=    Create Dictionary    TokenFailure=${SECURITY_DETAILS}
    &{durations}=    Create Dictionary    TokenFailure=${SECURITY_DURATION}
    Save Results To Excel
    ...    ${workbook}
    ...    ${json_directory}
    ...    ${data}
    ...    ${tooling}
    ...    ${skipped}
    ...    ${skipped_details}
    ...    ${durations}

Create Security Fake Sf Launcher
    [Documentation]    Create a platform-specific launcher for the deterministic fake sf fixture.
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
        ${chmod}=    Run Process    chmod    +x    ${launcher}
        Should Be Equal As Integers    ${chmod.rc}    0
    END
    RETURN    ${launcher}
