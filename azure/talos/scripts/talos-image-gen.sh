#!/bin/bash

#create directory to store images

mkdir -p manifests/image/talos

curl -o manifests/image/talos https://github.com/siderolabs/talos/releases/download/v1.2.7/azure-amd64.tar.gz

tar -xvzf manifests/image/talos/azure-amd64.tar.gz

#Install azure cli

curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

export CONNECTION = $(az storage account show-connection-string \
                    -n talosimagesa \
                    -g StorageRG \
                    -o tsv)

az storage blob upload \
  --connection-string $CONNECTION \
  --container-name talosimagecont \
  -f manifests/image/talos/disk.vhd \
  -n talos-azure.vhd

az image create \
  --name talos \
  --source https://talosimagesa.blob.core.windows.net/talosimagecont/disk.vhd \
  --os-type linux \
  -g StorageRG
