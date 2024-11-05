# RAZ1
## Linux
setup VRF on linux so I can use it in FRR
```
ip link add T01 type vrf table 101
ip link set dev T01 up
ip link set dev eth1 master T01
ip link set dev eth2 master T01
```
to make the above config persistent you need to add this to netplan
```
    vrfs:
        T01:
            table: 101
            interfaces:
            - eth1
            - eth2
```

## FRR
### Setup VRF
```
RAZ1# configure t
RAZ1(config)# 
RAZ1(config)# vrf T01 
RAZ1(config-vrf)# router-id 192.168.32.1
RAZ1(config-vrf)# q
RAZ1(config)# interface eth1 vrf T01
RAZ1(config-vrf)# q
RAZ1(config)# interface eth2 vrf T01
RAZ1(config-vrf)# q
RAZ1(config)# q
RAZ1# sh vrf 
vrf T01 id 5 table 101 (configured)
```
### Setup BGP

#### VRF-to-VRF Route exchange
**RD** - Route Distinguisher - RDs are only used within the router to distinguish between routes in different VRFs. They are not advertised beyond the router and are not part of routing or forwarding decisions on other routers in the network.

**RT** - Route target - Route Targets (RTs) control which routes are imported and exported between VRFs on the router.

**Comparison:**
- RD makes routes unique per VRF.
- RT defines route-sharing policies between VRFs.


If you want to export routes from one VRF to another you have to pass through the VPN.
Essentially what you do is
1. export from default VRF to VPN
2. import from VPN to a VRF ex. T01

In order to export you need to do 2 things in the source VRF
1. Specify the Route Distinguisher to be added to an exported route
2. Specifies the route-target list to be attached to a route (export) referring the configured Route Distinguisher
3. Say you want to export to VPN
Here is the configuration
```
router bgp 64513
...
 !
 address-family ipv4 unicast
  redistribute connected
  rd vpn export 64513:1
  rt vpn export 64513:1
  export vpn
 exit-address-family
exit
!
```

Now in order to import from the VPN to my VRF T01, I need to:
1. say I want to import
2. specify the route-target list to match
```
router bgp 65001 vrf T01
...
 !
 address-family ipv4 unicast
  redistribute connected
  rt vpn import 64513:1
  import vpn
 exit-address-family
exit
```
#### Current wotking config
```
Current configuration:
!
frr version 10.2-dev-MyOwnFRRVersion
frr defaults traditional
hostname RAZ1
log syslog informational
service integrated-vtysh-config
!
ip router-id 192.168.4.11
!
vrf T01
 ip router-id 192.168.32.1
exit-vrf
!
router bgp 64513
 bgp router-id 192.168.4.11
 neighbor 192.168.4.1 remote-as 64513
 neighbor 192.168.32.1 remote-as 65001
 !
 address-family ipv4 unicast
  redistribute connected
  rd vpn export 64513:1
  rt vpn import 65001:1
  rt vpn export 64513:1
  export vpn
  import vpn
 exit-address-family
exit
!
router bgp 65001 vrf T01
 bgp router-id 192.168.32.1
 neighbor 192.168.32.6 remote-as 65001
 neighbor 192.168.32.65 remote-as 65001
 !
 address-family ipv4 unicast
  redistribute connected
  rd vpn export 65001:1
  rt vpn import 64513:1
  rt vpn export 65001:1
  export vpn
  import vpn
 exit-address-family
exit
!
end
```






