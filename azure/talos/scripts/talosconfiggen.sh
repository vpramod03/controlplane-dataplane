#!/bin/sh

if [ $# -ne 3 ]
then
    echo "Usage: $0 dnsname port talosctlpath"
fi

while getopts ":h:p:t:" OPTION;
do
    case "${OPTION}" in
    h) 
       dnsname="$OPTARG" 
       ;;
    p) 
       port="$OPTARG" 
       ;;
    t) 
       talosctlpath="$OPTARG" 
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
echo ${port}
echo ${talosctlpath}

${talosctlpath}/talosctl gen config talosconfig-userdata https://${dnsname}:${port} --with-examples=false --with-docs=false --output-dir scripts/ --config-patch @scripts/patch.yaml  --config-patch '[{"op": "add", "path": "/machine/certSANs", "value": ['${dnsname}']}]' --force
${talosctlpath}/talosctl validate --config scripts/controlplane.yaml --mode cloud
if [ $? -eq 1 ]
then
    echo "scripts/controlplane.yaml is invalid"
    exit
fi

${talosctlpath}/talosctl validate --config scripts/worker.yaml --mode cloud

if [ $? -eq 1 ]
then
    echo "scripts/worker.yaml is invalid"
    exit
fi
