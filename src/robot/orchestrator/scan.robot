*** Settings ***
Documentation                                   Retrieve and log record counts for Salesforce objects from Excel list
Resource                                        ../resources/keywords.robot
Suite Teardown                                  Cleanup Suite

*** Test Cases ***
Object_Scanner
    Get All Object Record Counts
