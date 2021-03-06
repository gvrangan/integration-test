*** Settings ***
Documentation     Openstack library. This library is useful for tests to create network, subnet, router and vm instances
Library           SSHLibrary
Resource          Utils.robot
Resource          TemplatedRequests.robot
Resource          KarafKeywords.robot
Resource          ../variables/Variables.robot
Library           Collections
Library           String
Library           OperatingSystem

*** Variables ***
&{ITM_CREATE_DEFAULT}    tunneltype=vxlan    vlanid=0    prefix=1.1.1.1/24    gateway=0.0.0.0    dpnid1=1    portname1=BR1-eth1    ipaddress1=2.2.2.2
...               dpnid2=2    portname2= BR2-eth1    ipaddress2=3.3.3.3
&{L3VPN_CREATE_DEFAULT}    vpnid=4ae8cd92-48ca-49b5-94e1-b2921a261111    name=vpn1    rd=["2200:1"]    exportrt=["2200:1","8800:1"]    importrt=["2200:1","8800:1"]    tenantid=6c53df3a-3456-11e5-a151-feff819cdc9f
${VAR_BASE}       ${CURDIR}/../variables/vpnservice/
${ODL_FLOWTABLE_L3VPN}    21
${STATE_UP}       UP
${STATE_DOWN}     DOWN
${STATE_UNKNOWN}    UNKNOWN
${STATE_ENABLE}    ENABLED
${STATE_DISABLE}    DISABLE

*** Keywords ***
Basic Vpnservice Suite Setup
    SetupUtils.Setup_Utils_For_Setup_And_Teardown
    DevstackUtils.Devstack Suite Setup

Basic Vpnservice Suite Teardown
    # Delete three L3VPNs created using Multiple L3VPN Test
    Run Keyword And Ignore Error    VPN Delete L3VPN    vpnid=${VPN_INSTANCE_ID[0]}
    Run Keyword And Ignore Error    VPN Delete L3VPN    vpnid=${VPN_INSTANCE_ID[1]}
    Run Keyword And Ignore Error    VPN Delete L3VPN    vpnid=${VPN_INSTANCE_ID[2]}
    # Delete Vm instances from the given Instance List
    ${VM_INSTANCES} =    Create List    @{VM_INSTANCES_NET10}    @{VM_INSTANCES_NET20}
    : FOR    ${VmInstance}    IN    @{VM_INSTANCES}
    \    Run Keyword And Ignore Error    Delete Vm Instance    ${VmInstance}
    # Delete Neutron Ports from the given Port List.
    : FOR    ${Port}    IN    @{PORT_LIST}
    \    Run Keyword And Ignore Error    Delete Port    ${Port}
    # Delete Sub Nets from the given Subnet List.
    : FOR    ${Subnet}    IN    @{SUBNETS}
    \    Run Keyword And Ignore Error    Delete SubNet    ${Subnet}
    # Delete Networks in the given Net List
    : FOR    ${Network}    IN    @{NETWORKS}
    \    Run Keyword And Ignore Error    Delete Network    ${Network}
    # Remove security group created earlier
    Run Keyword And Ignore Error    Delete SecurityGroup    ${SECURITY_GROUP}
    Close All Connections

VPN Create L3VPN
    [Arguments]    &{Kwargs}
    [Documentation]    Create an L3VPN using the Json using the list of optional arguments received.
    Run keyword if    "routerid" in ${Kwargs}    Collections.Set_To_Dictionary    ${Kwargs}    router=, "router-id":"${Kwargs['routerid']}"
    ...    ELSE    Collections.Set_To_Dictionary    ${Kwargs}    router=${empty}
    &{L3vpn_create_actual_val} =    Collections.Copy_Dictionary    ${L3VPN_CREATE_DEFAULT}
    Collections.Set_To_Dictionary    ${L3vpn_create_actual_val}    &{Kwargs}
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/l3vpn_create    mapping=${L3vpn_create_actual_val}    session=session

VPN Get L3VPN
    [Arguments]    &{Kwargs}
    [Documentation]    Will return detailed list of the L3VPN_ID received
    ${resp} =    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/get_l3vpn    mapping=${Kwargs}    session=session
    Log    ${resp}
    [Return]    ${resp}

Associate L3VPN To Network
    [Arguments]    &{Kwargs}
    [Documentation]    Associate the created L3VPN to a network-id received as dictionary argument
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/assoc_l3vpn    mapping=${Kwargs}    session=session

Dissociate L3VPN From Networks
    [Arguments]    &{Kwargs}
    [Documentation]    Disssociate the already associated networks from L3VPN
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/dissoc_l3vpn    mapping=${Kwargs}    session=session

Associate VPN to Router
    [Arguments]    &{Kwargs}
    [Documentation]    Associate the created L3VPN to a router-id received as argument
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/assoc_router_l3vpn    mapping=${Kwargs}    session=session

Dissociate VPN to Router
    [Arguments]    &{Kwargs}
    [Documentation]    Dissociate the already associated routers from L3VPN
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/dissoc_router_l3vpn    mapping=${Kwargs}    session=session

VPN Delete L3VPN
    [Arguments]    &{Kwargs}
    [Documentation]    Delete the created L3VPN
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/l3vpn_delete    mapping=${Kwargs}    session=session

ITM Create Tunnel
    [Arguments]    &{Kwargs}
    [Documentation]    Creates Tunnel between the two DPNs received in the dictionary argument
    &{Itm_actual_val} =    Collections.Copy_Dictionary    ${ITM_CREATE_DEFAULT}
    Collections.Set_To_Dictionary    ${Itm_actual_val}    &{Kwargs}
    TemplatedRequests.Post_As_Json_Templated    folder=${VAR_BASE}/itm_create    mapping=${Itm_actual_val}    session=session

ITM Get Tunnels
    [Documentation]    Get all Tunnels and return the contents
    ${resp} =    RequestsLibrary.Get Request    session    ${CONFIG_API}/itm:transport-zones/
    Log    ${resp.content}
    Should Be Equal As Strings    ${resp.status_code}    200
    [Return]    ${resp.content}

ITM Delete Tunnel
    [Arguments]    ${zone-name}
    [Documentation]    Delete Tunnels created under the transport-zone
    ${resp} =    RequestsLibrary.Delete Request    session    ${CONFIG_API}/itm:transport-zones/transport-zone/${zone-name}/
    Log    ${resp.content}
    Should Be Equal As Strings    ${resp.status_code}    200
    [Return]    ${resp.content}

Verify Flows Are Present For L3VPN
    [Arguments]    ${ip}    ${vm_ips}
    [Documentation]    Verify Flows Are Present For L3VPN
    ${flow_output}=    Run Command On Remote System    ${ip}    sudo ovs-ofctl -O OpenFlow13 dump-flows br-int
    Log    ${flow_output}
    Should Contain    ${flow_output}    table=${ODL_FLOWTABLE_L3VPN}
    ${l3vpn_table} =    Get Lines Containing String    ${flow_output}    table=${ODL_FLOWTABLE_L3VPN},
    Log    ${l3vpn_table}
    : FOR    ${i}    IN    @{vm_ips}
    \    ${resp}=    Should Contain    ${l3vpn_table}    ${i}

Verify GWMAC Entry On ODL
    [Arguments]    ${GWMAC_ADDRS}
    [Documentation]    get ODL GWMAC table entry
    ${resp} =    RequestsLibrary.Get Request    session    ${VPN_PORT_DATA_URL}
    Log    ${resp.content}
    Should Be Equal As Strings    ${resp.status_code}    200
    : FOR    ${macAdd}    IN    @{GWMAC_ADDRS}
    \    Should Contain    ${resp.content}    ${macAdd}

Verify GWMAC Flow Entry Removed From Flow Table
    [Arguments]    ${cnIp}
    [Documentation]    Verify the GWMAC Table, ARP Response table and Dispatcher table.
    ${flow_output}=    Run Command On Remote System    ${cnIp}    sudo ovs-ofctl -O OpenFlow13 dump-flows br-int
    Log    ${flow_output}
    Should Contain    ${flow_output}    table=${GWMAC_TABLE}
    ${gwmac_table} =    Get Lines Containing String    ${flow_output}    table=${GWMAC_TABLE}
    Log    ${gwmac_table}
    #Verify GWMAC address present in table 19
    : FOR    ${macAdd}    IN    @{GWMAC_ADDRS}
    \    Should Not Contain    ${gwmac_table}    dl_dst=${macAdd} actions=goto_table:${L3_TABLE}

Verify ARP REQUEST in groupTable
    [Arguments]    ${group_output}    ${Group-ID}
    [Documentation]    get flow dump for group ID
    Should Contain    ${group_output}    group_id=${Group-ID}
    ${arp_group} =    Get Lines Containing String    ${group_output}    group_id=${Group-ID}
    Log    ${arp_group}
    Should Match Regexp    ${arp_group}    ${ARP_REQUEST_GROUP_REGEX}

Verify Tunnel Status as UP
    [Documentation]    Verify that the tunnels are UP
    ${output}=    Issue Command On Karaf Console    ${TEP_SHOW_STATE}
    Log    ${output}
    Should Contain    ${output}    ${STATE_UP}
    Should Not Contain    ${output}    ${STATE_DOWN}
    Should Not Contain    ${output}    ${STATE_UNKNOWN}

Verify Tunnel Status as DOWN
    [Documentation]    Verify that the tunnels are DOWN
    ${output}=    Issue Command On Karaf Console    ${TEP_SHOW_STATE}
    Log    ${output}
    Should Contain    ${output}    ${STATE_DOWN}
    Should Not Contain    ${output}    ${STATE_UP}
    Should Not Contain    ${output}    ${STATE_UNKNOWN}

Verify Tunnel Status as UNKNOWN
    [Documentation]    Verify that the tunnels are in Unknown state
    ${output}=    Issue Command On Karaf Console    ${TEP_SHOW_STATE}
    Log    ${output}
    Should Not Contain    ${output}    ${STATE_UP}
    Should Not Contain    ${output}    ${STATE_DOWN}
    Should Contain    ${output}    ${STATE_UNKNOWN}

Verify VXLAN interface
    [Documentation]    Verify that the VXLAN interfaces are Enabled
    ${output}=    Issue Command On Karaf Console    ${VXLAN_SHOW}
    Log    ${output}
    Should Contain    ${output}    ${STATE_UP}
    Should Contain    ${output}    ${STATE_ENABLE}
    Should Not Contain    ${output}    ${STATE_DISABLE}

Get Fib Entries
    [Arguments]    ${session}
    [Documentation]    Get Fib table entries from ODL session
    ${resp}    RequestsLibrary.Get Request    ${session}    ${FIB_ENTRIES_URL}
    Log    ${resp.content}
    [Return]    ${resp.content}
