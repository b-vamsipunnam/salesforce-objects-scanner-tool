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
${SF_COMMAND_TIMEOUT_SECONDS}          ${120}
${MAX_QUERY_TIMEOUT_SECONDS}           ${120}
${POLL_INTERVAL_SECONDS}               ${1.0}
${CONNECTEDAPP_TIMEOUT}                ${180}
${SF_TRANSIENT_RETRIES}                ${2}
${SF_RETRY_BACKOFF_SECONDS}            ${2.0}
@{SLOW_OBJECTS}                        ConnectedApplication

# Tooling API behavior
${INCLUDE_TOOLING}                     ${TRUE}
${ALLOW_DISABLED_DATACLOUD}            ${FALSE}

# Scan quality
${FAIL_ON_OPERATIONAL_ERRORS}          ${TRUE}
@{EXPECTED_SKIP_REASONS}               COUNT_NOT_SUPPORTED    QUERY_NOT_SUPPORTED
...                                    BIG_OBJECT_COUNT_UNSUPPORTED    RESTRICTIVE_FILTER_REQUIRED
...                                    DATACLOUD_INTENTIONALLY_DISABLED
@{TRANSIENT_FAILURE_REASONS}           EXTERNAL_OBJECT_EXCEPTION
...                                    REQUEST_LIMIT_EXCEEDED    UNKNOWN_EXCEPTION

# Object-specific Salesforce COUNT() limitations. These objects consistently
# return UNKNOWN_EXCEPTION even though discovery reports them as queryable.
@{KNOWN_UNKNOWN_DATA_OBJECTS}
...                                    ActivityFieldHistory    RecordActionHistory
@{KNOWN_UNKNOWN_TOOLING_OBJECTS}
...                                    InstalledSubscriberPackage

# Generated Robot suite formatting
${BACKSLASH}                           \\
${ELLIPSIS}                            ...
