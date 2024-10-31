#!/bin/bash

# Check for correct number of arguments
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <zone> <hostname> <ip-address>"
    exit 1
fi

ZONE=$1
HOSTNAME=$2
IP_ADDRESS=$3

# Add forward record
pdnsutil add-record "$ZONE" "$HOSTNAME" A "$IP_ADDRESS"

# Extract reverse lookup components
IFS='.' read -r -a ip_parts <<< "$IP_ADDRESS"
REVERSE_IP="${ip_parts[3]}.${ip_parts[2]}"
REVERSE_ZONE="${ip_parts[1]}.${ip_parts[0]}.in-addr.arpa"

# Add reverse record
# pdnsutil add-record "$REVERSE_ZONE" "$REVERSE_IP" PTR "$HOSTNAME"
echo "$REVERSE_ZONE" "$REVERSE_IP" PTR "$HOSTNAME.$ZONE"

echo "Forward and reverse records added successfully."
