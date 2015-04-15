*** Settings ***
Documentation     Test suite for AD-SAL Applications 
Suite Setup       Start Suite
Suite Teardown    Stop Suite
Library     SSHLibrary
Resource          ../../../libraries/Utils.txt

*** Variables ***
${start}=   sudo mn --controller=remote,ip=${CONTROLLER} --topo tree,2 

** Keywords ***