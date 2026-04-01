*** Settings ***
Documentation                                   Retrieve and log record counts for all queryable Salesforce objects using Salesforce CLI (sf), with filtering, timeout protection, and structured output generation.
Resource                                        ../resources/keywords.robot
Suite Teardown                                  Cleanup Suite

*** Test Cases ***
Object_Scanner
    Get All Object Record Counts                ${ORG_ALIAS}
