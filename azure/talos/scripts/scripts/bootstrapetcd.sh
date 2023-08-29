#!/bin/bash

if [ "$#" -ne 1 ]
then
    echo "Usage: $0 nodeipaddress"
fi

echo "node ip address is:"
echo "$1"

remoteip="$1"
count=0

while [ "$count" -le 20 ]
do
    echo "Waiting for Talos API to be up...."
    nc -zv "$remoteip" 50000
    if [ "$?" -eq 0 ]
    then
        echo "Talos API is up bootstrapping etcd"
        talosctl  --talosconfig scripts/talosconfig config endpoint "$remoteip"
        talosctl --talosconfig  scripts/talosconfig bootstrap --nodes "$remoteip"
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
