#!/bin/bash
# PREREQUISITE 1: make sure your kubectl context is with a namespace where the vault-tokenreviewer SA and secret have been created
read -p "What is your cluster's API endpoint?: " CLUSTER_API
read -p "What is the name of the SA on behalf of which cert manager will create tokens: " SA
read -p "What namespace does the SA reside in?: " SA_NS

# Strip the 'https://' prefix from CLUSTER_API
CLUSTER_API_STRIPPED=${CLUSTER_API#https://}
clusterName=${CLUSTER_API_STRIPPED%%.*}

# not using static JWT anymore
#JWT_TOKEN=$(kubectl -n $TOKEN_NS get secrets vault-tokenreviewer-token -o jsonpath='{.data.token}' | base64 --decode)

# we gather CA certs from the API server's endpoint
#CA_CERT=$(kubectl -n $TOKEN_NS get secrets vault-tokenreviewer-token -o jsonpath="{.data.ca\.crt}" | base64 --decode )
CA_CERT=$(echo | openssl s_client -connect $CLUSTER_API_STRIPPED -showcerts 2>/dev/null| openssl x509 -outform PEM)

# Because my clusters are on 6443 the ISSUER url needs to have the port as well, hence I will use $CLUSTER_API
# ISSUER=${CLUSTER_API%:*}q

vault auth enable -path=kubernetes/$clusterName kubernetes
vault write -f auth/kubernetes/$clusterName/config \
kubernetes_host="$CLUSTER_API" \
kubernetes_ca_cert="$CA_CERT" \
disable_local_ca_jwt="true" \
issuer="$CLUSTER_API"

# THE POLICY IS ALREADY CREATED - create a policy
vault policy write pki-guardanet-v1-ica1-v1 - <<EOF
path "guardanet_corp/v1/ica1/v1*"                        { capabilities = ["read", "list"] }
path "guardanet_corp/v1/ica1/v1/sign/guardanet-net"    { capabilities = ["create", "update"] }
path "guardanet_corp/v1/ica1/v1/issue/guardanet-net"   { capabilities = ["create"] }
EOF

# create a k8s auth ROLE that binds to an ISSUER's service account from ANY 
# That way we only need one role for now but at least we will have different ISSUERs per namespace so secrets that they will provision will be scoped to respective namespaces
# Generated vault tokens will be assigned the above pki-guardanetcorp-v1-ica1-v1 policy
vault write auth/kubernetes/$clusterName/role/issuer \
    bound_service_account_names=$SA \
    bound_service_account_namespaces=$SA_NS \
    audience="vault://$SA_NS/$SA" \
    policies=pki-guardanet-v1-ica1-v1 \
    ttl=10m
