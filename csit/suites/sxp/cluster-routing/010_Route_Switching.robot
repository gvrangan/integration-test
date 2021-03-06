*** Settings ***
Documentation     Test suite to test cluster connection switchover using virtual ip, this suite requires additional TOOLS_SYSTEM VM.
...               VM is used for its assigned ip-address that will be overlayed by virtual-ip used in test suites.
...               Resources of this VM are not required and after start of Test suite this node shutted down and to reduce routing conflicts.
Suite Setup       Setup Custom SXP Cluster Session
Suite Teardown    Clean Custom SXP Cluster Session
Test Teardown     Custom Clean SXP Cluster
Library           ../../../libraries/Sxp.py
Resource          ../../../libraries/ClusterManagement.robot
Resource          ../../../libraries/SxpClusterLib.robot

*** Variables ***
${SAMPLES}        1
${MAC_ADDRESS_TABLE}    &{EMPTY}
${VIRTUAL_IP_1}    ${TOOLS_SYSTEM_2_IP}
${VIRTUAL_INTERFACE_1}    eth0:0
${VIRTUAL_IP_MASK_1}    255.255.255.0

*** Test Cases ***
Route Definition Test
    [Documentation]    Test Route update mechanism without cluster node isolation
    Check Shards Status
    ${active_controller}    Get Active Controller
    Wait Until Keyword Succeeds    240    1    Ip Addres Should Not Be Routed To Follower    ${MAC_ADDRESS_TABLE}    ${VIRTUAL_IP_1}    ${active_controller}
    Add Route Definition To Cluster    ${VIRTUAL_IP_1}    ${VIRTUAL_IP_MASK_1}    ${VIRTUAL_INTERFACE_1}    ${active_controller}
    Wait Until Keyword Succeeds    240    1    Ip Addres Should Be Routed To Follower    ${MAC_ADDRESS_TABLE}    ${VIRTUAL_IP_1}    ${active_controller}
    Clean Routing Configuration To Controller    controller${active_controller}
    Wait Until Keyword Succeeds    240    1    Ip Addres Should Not Be Routed To Follower    ${MAC_ADDRESS_TABLE}    ${VIRTUAL_IP_1}    ${active_controller}
    Put Route Definition To Cluster    ${VIRTUAL_IP_1}    ${VIRTUAL_IP_MASK_1}    ${VIRTUAL_INTERFACE_1}    ${active_controller}
    Wait Until Keyword Succeeds    240    1    Ip Addres Should Be Routed To Follower    ${MAC_ADDRESS_TABLE}    ${VIRTUAL_IP_1}    ${active_controller}

Isolation of SXP service follower Test
    [Documentation]    Test Route update mechanism during Cluster isolation,
    ...    after each isolation virtual ip should be pre-routed to new leader
    Check Shards Status
    ${any_controller}    Get Any Controller
    Add Route Definition To Cluster    ${VIRTUAL_IP_1}    ${VIRTUAL_IP_MASK_1}    ${VIRTUAL_INTERFACE_1}    ${any_controller}
    : FOR    ${i}    IN RANGE    0    ${SAMPLES}
    \    ${controller_index}    Get Active Controller
    \    Isolate SXP Controller    ${controller_index}

*** Keywords ***
Put Route Definition To Cluster
    [Arguments]    ${virtual_ip}    ${VIRTUAL_IP_MASK}    ${VIRTUAL_INTERFACE}    ${follower}
    [Documentation]    Put Route definition to DS replacing all present
    ${route}    Route Definition Xml    ${virtual_ip}    ${VIRTUAL_IP_MASK}    ${VIRTUAL_INTERFACE}
    ${routes}    Route Definitions Xml    ${route}
    Put Routing Configuration To Controller    ${routes}    controller${follower}

Add Route Definition To Cluster
    [Arguments]    ${VIRTUAL_IP}    ${VIRTUAL_IP_MASK}    ${VIRTUAL_INTERFACE}    ${follower}
    [Documentation]    Add Route definition to DS
    ${old_routes}    Get Routing Configuration From Controller    controller${follower}
    ${route}    Route Definition Xml    ${VIRTUAL_IP}    ${VIRTUAL_IP_MASK}    ${VIRTUAL_INTERFACE}
    ${routes}    Route Definitions Xml    ${route}    ${old_routes}
    Put Routing Configuration To Controller    ${routes}    controller${follower}

Custom Clean SXP Cluster
    [Documentation]    Cleans up Route definitions
    ${follower}    Get Active Controller
    Clean Routing Configuration To Controller    controller${follower}

Setup Custom SXP Cluster Session
    [Documentation]    Prepare topology for testing, creates sessions and generate Route definitions based on Cluster nodes ip
    Shutdown Tools Node
    Setup SXP Cluster Session
    ${mac_addresses}    Map Followers To Mac Addresses
    Set Suite Variable    ${MAC_ADDRESS_TABLE}    ${mac_addresses}

Clean Custom SXP Cluster Session
    [Documentation]    Cleans up resources generated by test
    ${controller_index}    Get Active Controller
    Clean Routing Configuration To Controller    controller${controller_index}
    Clean SXP Cluster Session

Isolate SXP Controller
    [Arguments]    ${controller_index}
    [Documentation]    Isolate one of cluster nodes and perform check that virtual ip is routed to another cluster node,
    ...    afterwards unisolate old leader.
    Isolate_Member_From_List_Or_All    ${controller_index}
    Wait Until Keyword Succeeds    240    1    Sync_Status_Should_Be_False    ${controller_index}
    Wait Until Keyword Succeeds    240    1    Ip Addres Should Not Be Routed To Follower    ${MAC_ADDRESS_TABLE}    ${VIRTUAL_IP_1}    ${controller_index}
    ${active_follower}    Get Active Controller
    Wait Until Keyword Succeeds    240    1    Ip Addres Should Be Routed To Follower    ${MAC_ADDRESS_TABLE}    ${VIRTUAL_IP_1}    ${active_follower}
    Flush_Iptables_From_List_Or_All
    Wait Until Keyword Succeeds    240    1    Sync_Status_Should_Be_True    ${controller_index}
