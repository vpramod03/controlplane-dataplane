#!/bin/bash

if [ "$#" -ne 1 ]
then
    echo "Usage: $0 nodeipaddress talosctlpath"
fi

echo "node ip address is:"
echo "$1"

remoteip="$1"
talosctlpath="$2"
count=0

while [ "$count" -le 20 ]
do
    echo "Waiting for Talos API to be up...."
    nc -zv "$remoteip" 50000
    if [ "$?" -eq 0 ]
    then
        echo "Talos API is up bootstrapping etcd"
        ${talosctlpath}/talosctl  --talosconfig scripts/talosconfig config endpoint "$remoteip"
        ${talosctlpath}/talosctl --talosconfig  scripts/talosconfig bootstrap --nodes "$remoteip"
        break
    fi
    sleep 30
    count=$((count+1))
done

if [ "$count" -ge 20 ]
then
    echo "ERROR: Talos API is not up "
fi

echo "ETCD bootstrap Finished"
