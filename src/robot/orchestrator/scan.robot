*** Settings ***
Documentation                                   Discover Salesforce objects once and query them in parallel.
...                                             Generate consolidated JSON and Excel reports after all workers finish.
Resource                                        ../resources/keywords.robot


*** Test Cases ***
Object_Scanner
    [Documentation]                             Run the complete parallel object scan for the configured org alias.
    Get All Object Record Counts                ${ORG_ALIAS}
