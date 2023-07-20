#!/bin/bash


TALOS_API_IP = 50000

if [ "$#" -ne 1 ]
then
    echo "Usage: $0 nodeipaddress"
fi

echo "node ip address is:"
echo "$1"

remoteip="$1"
count=0

while [ "$count" -ge 20 ]
do
    echo "Waiting for Talos API to be up...."
    nc -zv "$remoteip" "$TALOS_API_IP"
    if [ "$?" -eq 0 ]
    then
        echo "Talos API is up bootstrapping etcd"
        talosctl  --talosconfig out/talosconfig config endpoint "$remoteip"
        talosctl  --talosconfig out/talosconfig config node "$remoteip"
        talosctl --talosconfig  out/talosconfig bootstrap "$remoteip"
        break
    fi
    sleep 30
    count += 1
done

if [ "$count" -ge 20 ]
then
    echo "ERROR: Talos API is not up "
fi

echo "ETCD bootstrap Finished"
