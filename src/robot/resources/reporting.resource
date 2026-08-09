*** Settings ***
Documentation    Run-directory, summary, JSON, and Excel reporting keywords.
Library          BuiltIn
Library          Collections
Library          DateTime
Library          OperatingSystem
Library          Process
Library          String
Resource         configuration.resource


*** Keywords ***
Generate Run Id
    [Documentation]    Return a filesystem-safe timestamp.
    ${timestamp}=    Get Time
    ${timestamp}=    Replace String    ${timestamp}    :    -
    ${timestamp}=    Replace String    ${timestamp}    ${SPACE}    -
    RETURN    ${timestamp}

Init Output Directory
    [Documentation]    Create and return an isolated scanner run directory.
    ${uuid}=    Evaluate    __import__('uuid').uuid4().hex
    ${run_id}=    Generate Run Id
    ${directory}=    Normalize Path    ${SCAN_OUTPUT_ROOT}${/}${RUN_PREFIX}${run_id}_${uuid}
    Create Directory    ${directory}
    Directory Should Exist    ${directory}
    RETURN    ${directory}

Init Json Directory
    [Documentation]    Create the final JSON report directory.
    [Arguments]    ${output_directory}
    ${directory}=    Normalize Path    ${output_directory}${/}json
    Create Directory    ${directory}
    RETURN    ${directory}

Generate Output File Name
    [Documentation]    Return the timestamped Excel workbook path.
    [Arguments]    ${output_directory}
    ${run_id}=    Generate Run Id
    ${path}=    Normalize Path    ${output_directory}${/}${OUTPUT_FILENAME}_${run_id}.xlsx
    RETURN    ${path}

Log Scan Summary
    [Documentation]    Print final success and skip counts.
    [Arguments]    ${data_results}    ${tooling_results}    ${skipped_reasons}
    ${data_count}=    Get Length    ${data_results}
    ${tooling_count}=    Get Length    ${tooling_results}
    ${skip_count}=    Get Length    ${skipped_reasons}
    ${total}=    Evaluate    $data_count + $tooling_count + $skip_count
    Log To Console    \n===== SUMMARY =====
    Log To Console    Success (Data): ${data_count}
    Log To Console    Success (Tooling): ${tooling_count}
    Log To Console    Skipped: ${skip_count}
    Log To Console    Total processed: ${total}
    Log To Console    ===================

Log Data Summary
    [Documentation]    Print successful data-object counts in sorted order.
    [Arguments]    ${data_results}
    Log To Console    \nData objects (Object: Count):
    ${keys}=    Get Dictionary Keys    ${data_results}
    Sort List    ${keys}
    FOR    ${key}    IN    @{keys}
        ${value}=    Get From Dictionary    ${data_results}    ${key}
        Log To Console    ${key}: ${value}
    END

Log Skipped Summary
    [Documentation]    Print skipped objects and their reasons.
    [Arguments]    ${skipped_reasons}
    Log To Console    \nSkipped objects:
    ${count}=    Get Length    ${skipped_reasons}
    IF    ${count} == 0
        Log To Console    (none)
        RETURN
    END
    ${keys}=    Get Dictionary Keys    ${skipped_reasons}
    Sort List    ${keys}
    FOR    ${key}    IN    @{keys}
        ${value}=    Get From Dictionary    ${skipped_reasons}    ${key}
        Log To Console    ${key}: ${value}
    END

Save Results To Excel
    [Documentation]    Save final JSON dictionaries and generate the Excel workbook.
    [Arguments]    ${workbook_path}
    ...    ${json_directory}
    ...    ${data_results}
    ...    ${tooling_results}
    ...    ${skipped_reasons}
    ...    ${durations}
    ${run_id}=    Generate Run Id
    ${data_file}=    Normalize Path    ${json_directory}${/}data_${run_id}.json
    ${tooling_file}=    Normalize Path    ${json_directory}${/}tooling_${run_id}.json
    ${skipped_file}=    Normalize Path    ${json_directory}${/}skipped_${run_id}.json
    ${durations_file}=    Normalize Path    ${json_directory}${/}durations_${run_id}.json
    ${data_json}=    Evaluate    json.dumps($data_results)    modules=json
    ${tooling_json}=    Evaluate    json.dumps($tooling_results)    modules=json
    ${skipped_json}=    Evaluate    json.dumps($skipped_reasons)    modules=json
    ${durations_json}=    Evaluate    json.dumps($durations)    modules=json
    Create File    ${data_file}    ${data_json}
    Create File    ${tooling_file}    ${tooling_json}
    Create File    ${skipped_file}    ${skipped_json}
    Create File    ${durations_file}    ${durations_json}
    ${result}=    Run Process
    ...    ${PYTHON}
    ...    ${CURDIR}${/}..${/}libraries${/}ExcelWriter.py
    ...    ${data_file}
    ...    ${tooling_file}
    ...    ${skipped_file}
    ...    ${durations_file}
    ...    ${workbook_path}
    Log To Console    ${result.stdout}
    Should Be Equal As Integers
    ...    ${result.rc}
    ...    0
    ...    msg=Excel generation failed:\n${result.stdout}\n${result.stderr}
