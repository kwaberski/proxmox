# DNS

## Intro
I use powerdns. PowerDNS consist of 3 elements
1. DNS authoritative server 
2. DNS recursor - recursive DNS server to resolve all public DNS queries
3. DNSdist - reverse proxy that allows for distributing DNS request across multiple servers


## PowerDNS Install
PowerDNS runs on a VM
hostname: ns1
IP: 192.168.2.6

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
enable the backend in powerdns (/etc/powerdns/pdns.conf) and point at the DB
```
launch=gsqlite3
gsqlite3-database=/var/lib/powerdns/pdns.sqlite3
```
Enabled API endpoint
```
api=yes
api-key=<API_KEY>
```
Enabled Webserver
```
webserver=yes
webserver-address=0.0.0.0
webserver-allow-from=127.0.0.1,::1,192.168.0.0/16
webserver-hash-plaintext-credentials=yes
webserver-port=8081
```

## DNS Configuration Management
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
