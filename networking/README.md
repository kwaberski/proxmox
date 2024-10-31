# Networking
## Diagram
[Network Diagram](https://miro.com/app/board/uXjVKkbvlZQ=/?moveToWidget=3458764603058569259&cot=14)

## Proxmox Host 
Proxmox host networking is defined in /etc/network/interfaces
```
auto lo
iface lo inet loopback

# USB - Bus 004 Device 004: ID 0bda:8153 Realtek Semiconductor Corp. RTL8153 Gigabit Ethernet Adapter
auto enx00e04c68038b
iface enx00e04c68038b

auto dmzbr0
iface dmzbr0 inet static
        address 192.168.1.35/24
        gateway 192.168.1.1
        bridge-ports enx00e04c68038b
        bridge-stp off
        bridge-fd 0
#       ip-forward on


# PCI - 02:00.0 Network controller: Intel Corporation Wi-Fi 6 AX200 (rev 1a)
# auto wlx18d6c70f01f1
# iface wlx18d6c70f01f1 inet dhcp

# PCI - 01:00.0 Ethernet controller: Realtek Semiconductor Co., Ltd. RTL8111/8168/8411 PCI Express Gigabit Ethernet Controller (rev 15)
#
iface enp1s0 inet manual
auto vmbr0
iface vmbr0 inet static
        address 192.168.2.35/24
        gateway 192.168.2.1
        bridge-ports enp1s0
        bridge-stp off
        bridge-fd 0
        ip-forward on


source /etc/network/interfaces.d/*
```

## Proxmox SDN
SDN configuration is define in /etc/network/interfaces.d/sdn

To see existing bridges
```
ip link show type bridge
```

To see veth "tunnel" establishing <=IN/OUT=> connections between "bridge ports"
```
ip link show type veth
```

## DHCP
The DHCP plugin in Proxmox VE SDN can be used to automatically deploy a DHCP server for a Zone. It provides DHCP for all Subnets in a Zone that have a DHCP range configured. Currently the only available backend plugin for DHCP is the dnsmasq plugin.

The DHCP plugin works by allocating an IP in the IPAM plugin configured in the Zone when adding a new network interface to a VM/CT.

**IMPORTANT:**
**- You also need to have a gateway configured for the subnet - otherwise automatic DHCP will not work.**
**- DHCP server needs a source ip address and currently Proxmox reuses the ip of gateway for that, and sends a default gw route pointing at that IP address**
```
# cat /etc/dnsmasq.d/simple/10-corp3.conf 
dhcp-option=tag:simple-192.168.3.0-24,option:router,192.168.3.1
dhcp-range=set:simple-192.168.3.0-24,192.168.3.0,static,255.255.255.0,infinite
interface=corp3
```
```json
# pvesh get /cluster/sdn/vnets/corp3/subnets --output-format json | jq .
[
  {
    "cidr": "192.168.3.0/24",
    "dhcp-range": [
      {
        "end-address": "192.168.3.126",
        "start-address": "192.168.3.65"
      }
    ],
    "digest": "0566c8f8b5288d52ab2dd4cbe58d7207dd258490",
    "dnszoneprefix": "corp3",
    "gateway": "192.168.3.1",
    "id": "simple-192.168.3.0-24",
    "mask": "24",
    "network": "192.168.3.0",
    "subnet": "simple-192.168.3.0-24",
    "type": "subnet",
    "vnet": "corp3",
    "zone": "simple"
  }
]
```
### Fix 1
1. Set the gateway address on the subnet to IPa
2. modify /etc/dnsmasq.d/<zone>/10-<vnet>>.conf
```
dhcp-option=tag:simple-192.168.3.0-24,option:router,<IPb>
```
that way you will have one IP that DHCP will use and a different IP that DHCP will send as a default GW

### Fix 2
use cloud init to ignore DHCP routes
1. create a cloud init file /var/lib/vz/snippets/dhcp-ignoredhcproutes.yaml
```yaml
#cloud-config
network:
  version: 2
  ethernets:
    ens18:
      dhcp4: true
      dhcp4-overrides:
        use-routes: false
```
2. apply to a VM
```
qm set 107 --cicustom "network=local:snippets/dhcp-ignoredhcproutes.yaml"
```

## Cloud Init
To begin with on Ubuntu you need to get rid of existing cloud init
```
apt purge cloud-init
apt update -y
apt install cloud-init
sudo mv /var/lib/cloud/data/upgraded-network /var/lib/cloud/data/upgraded-network.backup
sudo cloud-init init
```

Before the VM starts the custom file is accessed and placed into an ISO file, which is then fed to the VM as a cdrom.

to set a custom cloud init configuration on a VM
```
qm set 105 --cicustom "network=local:snippets/dhcp-ignoredhcproutes.yaml"
```
to dump existing cloud init config
```
qm cloudinit dump 105 network
```
**The "cloudinit dump" only shows the configuration of the built-in cloud-init configuration. If you add a custom snippet - it will not be shown in that command output.**

### Troubleshooting Cloud Init
the below allows to check if received cloud init at boot time is ok
```
sudo cloud-init schema --system
```

## Performance

### Simple Zone
#### With DG configured on the VNET's subnet
I create a VNET (ie. a bridge) and add a subnet and specify an IP for DG on the subnet.
This adds the IP address to the bridge interface on Proxmox and I get connectivity between VNets through the Proxmox OS routing table which automatically picks up interfaces and adds routes to their
related subnets

| Connection Type              | Throughput |
| ---------------------------- | ---------- |
| VM-to-VM off the same Bridge | 6Gbps      |
| VM-to-VM different Bridges   | 3Gbps      |

#### Without DG configured on the VNET's subnet
This means that in order for VMs on two different bridghes to see each other I need a router
where both of these bridges connect to. So I set up a VM and add two interfaces to the VM each
on each of the 2 bridges

| Connection Type                                    | Throughput |
| -------------------------------------------------- | ---------- |
| VM-to-VM different Bridges through a VM (router)   | 4.5Gbps    |

# Private Cloud Networking
Egress routing under normal conditions uses my NOS router, the NGGW2 firewall forwards directly to the NOS Router (NOSGAteway)
Should the NOS router become unavailable the firewall (NGGW2) will use its second best option the IG, which uses the underlying host's (beelink's)
WiFi to connecto to a mobile data network (ex. through a hotpsot on my phone)

## Gateways

Corp ----- (CORP) NGGW2 (WAN) ----- (Gateway Group: InternetAccess) ----- tier 1 -----> NOSGateway (192.168.1.1)
                    |                                               |
                  (RTN)                                             |--- tier 2 -----> IG (192.168.1.3) ----- NOSGateway (192.168.1.1)
                    |                                                                                   |
                                                                                                        |---- WIFI 

## BGP
NGGW2 (pfsense) runs a BGP instance and advertises its connected routes
Currently the only neighbor is the IG (192.168.1.3) 

## IG
This is an Internet Gateway that serves the purposes of providing Internet access to the provate cloud 
through mobile data connection over its WiFi interface.
IG has iptables set to Masquerade outbound traffic on its interfaces
```
Chain POSTROUTING (policy ACCEPT 43 packets, 2580 bytes)
 pkts bytes target     prot opt in     out     source               destination         
 1555  118K MASQUERADE  all  --  *      wls16   0.0.0.0/0            0.0.0.0/0           
 1115 81572 MASQUERADE  all  --  *      eth0    192.168.0.0/16      !192.168.0.0/16  
```
