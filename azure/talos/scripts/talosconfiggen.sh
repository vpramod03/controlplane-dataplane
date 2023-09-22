#!/bin/sh

if [ $# -ne 2 ]
then
    echo "Usage: $0 dnsname port"
fi

while getopts "h:p" OPTION;
do
    case "${OPTION}" in
    h) 
       dnsname="$OPTARG" 
       ;;
    p) 
       port="$OPTARG" 
       ;;
    esac
done
#if ! command -v talosctl &> /dev/null
#then
#    echo "Installing talos cli"
#    curl -sL https://talos.dev/install | sh
#else
#    echo "talosctl is already installed skipping.."
#fi

if [ -f scripts/controlplane.yaml ]
then
   rm -f scripts/controlplane.yaml
fi

if [ -f scripts/wokrer.yaml ]
then
   rm -f scripts/worker.yaml
fi

if [ -f scripts/talosconfig ]
then
   rm -f scripts/talosconfig
fi

echo ${dnsname}
echo ${4}
../../../capten/talosctl gen config talosconfig-userdata https://${dnsname}:${4} --with-examples=false --with-docs=false --output-dir scripts/ --config-patch @scripts/patch.yaml --force
../../../capten/talosctl validate --config scripts/controlplane.yaml --mode cloud
if [ $? -eq 1 ]
then
    echo "scripts/controlplane.yaml is invalid"
    exit
fi

../../../capten/talosctl validate --config scripts/worker.yaml --mode cloud

if [ $? -eq 1 ]
then
    echo "scripts/worker.yaml is invalid"
    exit
fi
