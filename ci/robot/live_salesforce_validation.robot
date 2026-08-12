*** Settings ***
Documentation     Opt-in validation of the real Salesforce CLI and Pabot artifact path.
Library           Collections
Library           OperatingSystem
Resource          ../../src/robot/resources/keywords.robot


*** Test Cases ***
Validate One Live Salesforce Object
    [Documentation]    Count Organization through the production Pabot query and artifact keywords.
    VAR    ${ORG_ALIAS}    ${ORG_ALIAS}    scope=SUITE
    Normalize Scanner Configuration
    Validate Org Alias
    Check Prerequisites
    ${run_directory}=    Normalize Path    ${OUTPUT DIR}${/}live-scanner
    Create Directory    ${run_directory}
    @{data_objects}=    Create List    Organization
    @{tooling_objects}=    Create List
    ${data_results}    ${tooling_results}    ${skipped_reasons}    ${skipped_details}    ${durations}=
    ...    Run Object Queries With Pabot
    ...    ${data_objects}
    ...    ${tooling_objects}
    ...    ${run_directory}
    Dictionary Should Contain Item    ${data_results}    Organization    ${1}
    Should Be Empty    ${tooling_results}
    Should Be Empty    ${skipped_reasons}
    Should Be Empty    ${skipped_details}
    Dictionary Should Contain Key    ${durations}    Organization
    Validate Scan Quality    ${skipped_reasons}
