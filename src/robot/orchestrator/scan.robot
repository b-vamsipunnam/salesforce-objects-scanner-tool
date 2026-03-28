*** Settings ***
Documentation                                   Retrieve and log record counts for Salesforce objects from Excel list
Resource                                        ../resources/keywords.robot
Suite Teardown                                  Cleanup Suite

*** Variables ***
# Set this to the same alias used in: sf org login web --alias <org_name>
${ORG_ALIAS}              MyOrg

*** Test Cases ***
Object_Scanner
    Get All Object Record Counts
