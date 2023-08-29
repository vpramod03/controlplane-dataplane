#!/bin/bash

#create directory to store images

mkdir -p manifests/image/talos

wget -P manifests/image/talos/ https://github.com/siderolabs/talos/releases/download/v1.5.0/azure-amd64.vhd.xz 

xz -d manifests/image/talos/azure-amd64.vhd.xz

#Install azure cli

#curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

export CONNECTION=$(az storage account show-connection-string \
                    -n talosimagesa \
                    -g StorageRG \
                    -o tsv)
echo $CONNECTION
az storage blob upload \
  --connection-string $CONNECTION \
  --container-name talosimagecont \
  -f manifests/image/talos/azure-amd64.vhd \
  -n talos-azure.vhd \
  --overwrite

#az image create \
#  --name talos \
#  --source https://talosimagesa.blob.core.windows.net/talosimagecont/talos-azure.vhd \
#  --os-type linux \
#  -g StorageRG
