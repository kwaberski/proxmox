# DNS

## Intro
I use powerdns. PowerDNS consist of 3 elements
1. DNS authoritative server 
2. DNS recursor - recursive DNS server to resolve all public DNS queries
3. DNSdist - reverse proxy that allows for distributing DNS request across multiple servers


## Install PowerDNS Server and Recurson
PowerDNS runs on a VM
hostname: ns1
IP: 192.168.2.6
### Server
[PowerDNS Repos](https://repo.powerdns.com/)

Create the file '/etc/apt/sources.list.d/pdns.list' with this content:
```
deb [signed-by=/etc/apt/keyrings/auth-49-pub.asc] http://repo.powerdns.com/ubuntu jammy-auth-49 main
```
Put this in '/etc/apt/preferences.d/auth-49':
```
Package: auth*
Pin: origin repo.powerdns.com
Pin-Priority: 600
```
and execute the following commands:
```
sudo install -d /etc/apt/keyrings; curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo tee /etc/apt/keyrings/auth-49-pub.asc &&
sudo apt-get update &&
sudo apt-get install pdns-server
```
### Recursor
Create the file '/etc/apt/sources.list.d/pdns.list' with this content:
```
deb [signed-by=/etc/apt/keyrings/rec-51-pub.asc] http://repo.powerdns.com/ubuntu jammy-rec-51 main
```
Put this in '/etc/apt/preferences.d/rec-51':
```
Package: rec*
Pin: origin repo.powerdns.com
Pin-Priority: 600
```
and execute the following commands:
```
sudo install -d /etc/apt/keyrings; curl https://repo.powerdns.com/FD380FBB-pub.asc | sudo tee /etc/apt/keyrings/rec-51-pub.asc &&
sudo apt-get update &&
sudo apt-get install pdns-recursor
```
### Install and Configure Database backend
```
sudo apt install pdns-backend-sqlite3
```
create a database according to a provided schema
```
sudo mkdir /var/lib/powerdns
sudo sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns-backend-sqlite3/schema.sqlite3.sql
sudo chown -R pdns:pdns /var/lib/powerdns
```
### Configure PowerDNS Server
1. Configure DNS server to listen only on local interface on port 5353.
We do that because we want to have a PowerDNS Recursor in front.

So first change netplan config to create a dedicate loopback IP for that
Edit /etc/netplan/50-cloud-init.yaml
```yaml
    ethernets:
        lo:
            match:
              name: lo
            addresses:
            - 127.0.0.1/24
            - 127.0.1.1/24
```

Now edit /etc/powerdns/pdns.conf
```
local-port=5353
local-address=127.0.1.1
```

2. enable the backend in powerdns (/etc/powerdns/pdns.conf) and point at the DB
```
launch=gsqlite3
gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
```
3. Enable API endpoint
```
api=yes
api-key=<API_KEY>
```
4. Enable Webserver
```
webserver=yes
webserver-address=0.0.0.0
webserver-allow-from=127.0.0.1,::1,192.168.0.0/16
webserver-hash-plaintext-credentials=yes
webserver-port=8081
```
### Configure PowerDNS Recursor
Edit /etc/powerdns/recursor.conf to lool as follows
```yaml
dnssec:
  validation: process # default
  trustanchorfile: /usr/share/dns/root.key
recursor:
  hint_file: /usr/share/dns/root.hints
  include_dir: /etc/powerdns/recursor.d
  forward_zones:
    - zone: guardanet.net
      forwarders:
      - 127.0.1.1:5353
incoming:
  listen:
  - 127.0.0.1 # default
  - 192.168.2.6
  allow_from: [127.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 169.254.0.0/16, 192.168.0.0/16, 172.16.0.0/12, '::1/128', 'fc00::/7', 'fe80::/10']
outgoing:
 source_address:
 - 0.0.0.0 # default
```

## DNS DB Configuration Management
### pdnsutil
```
sudo -u pdns pdnsutil create-zone guardanet.net ns1.guardanet.net
sudo -u pdns pdnsutil add-record guardanet.net '' MX '25 mail.guardanet.net'
sudo -u pdns pdnsutil add-record guardanet.net '' MX '25 mail.guardanet.net'
sudo -u pdns pdnsutil add-record guardanet.net. ns1 A 192.168.2.6
sudo -u pdns pdnsutil create-zone 168.192.in-addr.arpa. ns1.guardanet.net
```
new forward and reverse zone for tenant 01  
```
sudo -u pdns pdnsutil create-zone t01.infra.guardanet.net ns1.guardanet.net
sudo -u pdns pdnsutil create-zone 32.168.192.in-addr.arpa. ns1.guardanet.net
```

### API
```
curl -v -H 'X-API-Key: <API_KEY>' http://127.0.0.1:8081/api/v1/servers/localhost/zones
curl -v -H 'X-API-Key: <API_KEY>' http://127.0.0.1:8081/api/v1/servers/localhost/zones/guardanet.net.
```
### Quering
```
dig 65.4.168.192.in-addr.arpa. PTR @192.168.2.6
dig ns1.guardanet.net @192.168.2.6
```
### Edidting a zone
Edit the zone by running
```
sudo -u pdns pdnsutil edit-zone guardanet.net.
```
now save with Ctrl+O and exit 
you will be asked to uncrease the serial number and reload


# Blocking Ads 
## Create a blocklist
[PowerDNS AdBlock](https://gist.github.com/ahupowerdns/bb1a043ce453a9f9eeed)
[MikroTik](https://github.com/tvwerkhoven/mikrotik_adblock?tab=readme-ov-file)
1. Install swift
```
wget https://download.swift.org/swift-6.0.1-release/ubuntu2004/swift-6.0.1-RELEASE/swift-6.0.1-RELEASE-ubuntu20.04.tar.gz
sudo tar -xvzf swift-6.0.1-RELEASE-ubuntu20.04.tar.gz -C /usr/local/
echo 'export PATH=$PATH:/usr/local/swift-6.0.1-RELEASE-ubuntu20.04/usr/bin' >> ~/.bashrc
source ~/.bashrc
```
2. Clone the PowerDNS AdBlock repo and get the blocklist
```
git clone https://github.com/mozilla/focus.git
cd ../focus/
./checkout.sh
cd focus-ios/Lists/
( echo 'return{'; for a in $(jq '.[].trigger["url-filter"]' disconnect-advertising.json  | cut -f3 -d? | sed 's:\\\\.:.:g' | sed s:\"::); do     echo \"$a\", ; done ; echo '}'; ) > blocklist.lua
```
3. Clone the MikroTik repo and create a list
Make sure in line 14 in the if statement you put an \ENTER\ before then
```
git clone https://github.com/tvwerkhoven/mikrotik_adblock.git
./mkadblock.sh vyos
```
4. Copy the two bloclists to a folder and merge them
```
(cat <(sed 's/}/,/g' adblock.all.vyos.txt | tr -d '\n') <(sed 's/return{//g' blocklist.lua | tr -d '\n') ) > adblocklist.lua
```
5. Now place the adblocklist.lua file on the DNS server in the /etc/powerdns directory. 
4. Copy the adblock2.lua to the DNS server and put it the /etc/powerdns directory
5. Edit the recursor.conf on the DNS server to add
```yaml
recursor:
  lua_dns_script: /etc/powerdns/adblock2.lua
```
6. Restart the recurson
```
sudo systemctl restart pdns-recursor.service
```
7. Teat
```
dig adready.com @192.168.2.6

; <<>> DiG 9.18.28-0ubuntu0.22.04.1-Ubuntu <<>> adready.com @192.168.2.6
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 45554
;; flags: qr rd ra; QUERY: 1, ANSWER: 0, AUTHORITY: 0, ADDITIONAL: 1

;; OPT PSEUDOSECTION:
; EDNS: version: 0, flags:; udp: 512
;; QUESTION SECTION:
;adready.com.                   IN      A

;; Query time: 0 msec
;; SERVER: 192.168.2.6#53(192.168.2.6) (UDP)
;; WHEN: Wed Oct 16 18:37:10 UTC 2024
;; MSG SIZE  rcvd: 40
```
