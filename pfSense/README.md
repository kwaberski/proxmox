# pfSense
## Block DoH
https://github.com/jpgpi250/piholemanual/tree/master
https://github.com/jpgpi250/piholemanual/blob/master/doc/Block%20DOH%20with%20pfsense.pdf

### Exception
1. Find an IP associated with a FQDN
2. Find what network this IP belongs to if you want to allow the whole network. To do that go to 
```
curl -s https://api.bgpview.io/ip/76.76.21.142 | jq '.data.prefixes[].prefix'
```
3. Create an alias **ExceptionsDoHServersIPv4** and add the network to the Alias
4. Add a rule using the alias with Accept action. **Make sure the rule is above the block rule**