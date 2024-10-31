# Routing

1. Here I configure a prefix list to only use a default route
2. I then configure a route map to only advertise the default route if it matches the specified interface. This is to only advertise a default route if it goes out the WLS16 interface. I also set the next hop to be pointing at myself otherwise the route;s next hop as I see it will be send to my BGP peer, who can see it.
```
route-map DFGW_ONLY_WIFI permit 10
 match interface wls16
 match ip address prefix-list DFGW_ONLY
 set ip next-hop 192.168.1.3
```

3. I need to make sure that route is present in BGP
```
    redistribute kernel route-map DFGW_ONLY_WIFI
```
3. Apply the routemap to my neighbor
```
  neighbor 192.168.1.2 route-map DFGW_ONLY_WIFI out
```

Here is the full config
```
IG# show running-config 
Building configuration...

Current configuration:
!
frr version 10.2-dev-MyOwnFRRVersion
frr defaults traditional
hostname IG
log syslog informational
service integrated-vtysh-config
!
ip prefix-list DFGW_ONLY seq 5 permit 0.0.0.0/0
!
debug bgp updates in
debug bgp updates out
!
router bgp 64513
 bgp router-id 192.168.1.3
 no bgp ebgp-requires-policy
 neighbor 192.168.1.2 remote-as 64513
 !
 address-family ipv4 unicast
  redistribute kernel route-map DFGW_ONLY_WIFI
  neighbor 192.168.1.2 route-map DFGW_ONLY_WIFI out
 exit-address-family
exit
!
route-map DFGW_ONLY_WIFI permit 10
 match interface wls16
 match ip address prefix-list DFGW_ONLY
 set ip next-hop 192.168.1.3
exit
!
end
```