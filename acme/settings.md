# No EAB
https://vault.corp.guardanet.net:8200/v1/guardanet_corp/v1/ica2/v1/acme/directory

()
Generating ACME account key..
Registering ACME account..
Registration successful, account URL: 'https://vault.corp.guardanet.net:8200/v1/guardanet_corp/v1/ica2/v1/acme/account/d66102e1-4844-2c69-22df-637639861cdd'
TASK OK


# EAB
https://vault.corp.guardanet.net:8200/v1/guardanet_corp/v1/ica2/v1/roles/infra-guardanet-net-subdomain/acme/directory

$ vault write -f guardanet_corp/v1/ica2/v1/roles/infra-guardanet-net-subdomain/acme/new-eab
Key               Value
---               -----
acme_directory    roles/infra-guardanet-net-subdomain/acme/directory
created_on        2024-10-25T14:50:33Z
id                547cfdd0-0a42-b0a8-f401-2d149bac1174
key               vault-eab-0-SQyzcWQjXXdI6lmZZBYKHnuylCTm1dm8CyGmZs6yXJo
key_type          hs


Generating ACME account key..
Registering ACME account.. 
TASK ERROR: Registration failed: Error: POST to https://vault.corp.guardanet.net:8200/v1/guardanet_corp/v1/ica2/v1/roles/infra-guardanet-net-subdomain/acme/new-account {"type":"urn:ietf:params:acme:error:malformed","detail":"eab payload does not match outer JWK key: The request message was malformed","subproblems":null} 



Setting up ACME DNS Plugin
https://192.168.2.35:8006/pve-docs/pve-admin-guide.html#sysadmin_certs_acme_plugins
https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_pdns