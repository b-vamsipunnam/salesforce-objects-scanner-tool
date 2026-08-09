*** Settings ***
Documentation    Configuration defaults shared by scanner resources.


*** Variables ***
# Executables and Salesforce target
${SF_CLI}                              sf
${PYTHON}                              python
${ORG_ALIAS}                           ${EMPTY}

# Run output
${SCAN_OUTPUT_ROOT}                    ${EXECDIR}${/}output
${OUTPUT_FILENAME}                     SF_Objects
${RUN_PREFIX}                          Run_
${VERBOSE_OBJECT_RESULTS}              ${FALSE}

# Parallel execution
${PABOT_PROCESSES}                     ${4}
${PABOT_SHARDS_PER_PROCESS}            ${4}

# Query timing
${MAX_QUERY_TIMEOUT_SECONDS}           ${120}
${POLL_INTERVAL_SECONDS}               ${1.0}
${CONNECTEDAPP_TIMEOUT}                ${180}
@{SLOW_OBJECTS}                        ConnectedApplication

# Tooling API behavior
${INCLUDE_TOOLING}                     ${TRUE}

# Scan quality
${FAIL_ON_OPERATIONAL_ERRORS}          ${TRUE}
@{EXPECTED_SKIP_REASONS}               COUNT_NOT_SUPPORTED    REQUIRES_WHERE_StatType
...                                    INVALID_TYPE_FOR_OPERATION    BIG_OBJECT_UNSUPPORTED_OPERATION
...                                    MALFORMED_QUERY    INVALID_TYPE    INSUFFICIENT_ACCESS
...                                    EXTERNAL_OBJECT_EXCEPTION    EXTERNAL_OBJECT_UNSUPPORTED_EXCEPTION
...                                    DATACLOUD_API_DISABLED_EXCEPTION    DEPENDENCY_API_UNSUPPORTED_EXCEPTION
...                                    ID_REQUIRED
@{OPERATIONAL_FAILURE_REASONS}         INVALID_JSON_OUTPUT    INVALID_JSON_STRUCTURE
...                                    INVALID_SESSION_ID    REQUEST_LIMIT_EXCEEDED
...                                    TIMEOUT    OTHER_ERROR    UNKNOWN_EXCEPTION
...                                    TOOLING_DISCOVERY_FAILED    WORKER_ERROR

# Generated Robot suite formatting
${BACKSLASH}                           \\
${ELLIPSIS}                            ...
