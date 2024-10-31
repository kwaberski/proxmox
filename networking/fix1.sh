#!/bin/bash
read -p "Please enter zone name: " ZONE
cd /etc/dnsmasq.d/$ZONE

ls 10* | while read sn

do 
    # backup
    mkdir .backup
    cp $sn .backup/$sn
    OLD_GW=$(cat $sn | head -1 | cut -f 3 -d ',')
    OLD_GW_1ST3=$(echo "$OLD_GW" | cut -d '.' -f 1-3)
    NUMBER=$(echo $OLD_GW | cut -f 4 -d'.')
    NEW_NUMBER=$((NUMBER - 1))
    NEW_GW=$OLD_GW_1ST3.$NEW_NUMBER

    sed -i "s/$OLD_GW/$NEW_GW/g" $sn
done

systemctl restart dnsmasq@$ZONE



