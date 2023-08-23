terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
    features {}
  
}

resource "azurerm_resource_group" "storagerg" {
  name     = "StorageRG"
  location = var.region
}    

resource "azurerm_storage_account" "talosimagesa" {
  name                     = "talosimagesa"
  resource_group_name      = "${azurerm_resource_group.storagerg.name}"
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "talosaz"
  }
}


resource "azurerm_storage_container" "talosimagecont" {
  name                  = "talosimagecont"
  storage_account_name  = azurerm_storage_account.talosimagesa.name
  container_access_type = "private"
}

resource "null_resource" "talosimagecreate" {

    provisioner "local-exec" {
        command = "/bin/bash scripts/talos-image-gen.sh"
    }
    depends_on = [
      azurerm_storage_container.talosimagecont
    ]
}

#resource "azurerm_storage_blob" "talosimageblob" {
#  name = "talosimageblob"
#  storage_account_name = azurerm_storage_account.talosimagesa.name
#  storage_container_name = azurerm_storage_container.talosimagecont.name
#  source = "manifests/image/talos/azure-amd64.vhd"
#  type = "Block"

#}

resource "azurerm_image" "talosimage" {
  name                      = "talos-azure"
  location                  = var.region
  resource_group_name       = azurerm_resource_group.storagerg.name
  
  os_disk {
    os_type = "Linux"
    os_state = "Generalized"
    blob_uri = "https://${azurerm_storage_account.talosimagesa.name}.blob.core.windows.net/${azurerm_storage_container.talosimagecont.name}/talos-azure.vhd"
  }
}

resource "azurerm_resource_group" "talosrg" {
  name     = "talosrg"
  location = var.region
}  

resource "azurerm_virtual_network" "talosnet" {
    name = "talosnet"
    address_space = [ "10.0.0.0/16" ]
    location = var.region
    resource_group_name = azurerm_resource_group.talosrg.name
  
}

resource "azurerm_subnet" "talossubnet" {
    name = "talossubnet"
    resource_group_name = azurerm_resource_group.talosrg.name
    virtual_network_name = azurerm_virtual_network.talosnet.name
    address_prefixes = [ "10.0.1.0/24" ]
  
}

resource "azurerm_network_security_group" "talossg" {
    name = "talossg"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region  
}

resource "azurerm_network_security_rule" "apid" {
    name = "apid"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1001"
    source_port_range  = "*"
    destination_port_ranges = [ "50000" ]
    source_address_prefix  = "*"
    destination_address_prefix  = "*"
    direction = "Inbound"
    access = "Allow"
    resource_group_name = azurerm_resource_group.talosrg.name
    protocol = "Tcp"

}

resource "azurerm_network_security_rule" "trustd" {
    name = "trustd"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1002"
    source_port_range = "*"
    destination_port_ranges = [ "50001" ]
    source_address_prefix  = "*"
    destination_address_prefix  = "*"
    direction = "Inbound"
    access = "Allow"
    resource_group_name = azurerm_resource_group.talosrg.name
    protocol = "Tcp"

}

resource "azurerm_network_security_rule" "etcd" {
    name = "etcd"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1003"
    source_port_range = "*"
    destination_port_ranges = [ "2379-2380" ]
    source_address_prefix  = "*"
    destination_address_prefix  = "*"
    direction = "Inbound"
    access = "Allow"
    resource_group_name = azurerm_resource_group.talosrg.name
    protocol = "Tcp"

}

resource "azurerm_network_security_rule" "kube" {
    name = "kube"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1004"
    source_port_range = "*"
    destination_port_ranges = [ "6443" ]
    source_address_prefix  = "*"
    destination_address_prefix  = "*"
    direction = "Inbound"
    access = "Allow"
    resource_group_name = azurerm_resource_group.talosrg.name
    protocol = "Tcp"

}

resource "azurerm_public_ip" "talos-public-ip" {
    count = var.mastercount
    name = element(concat(var.publicipname, [""]), count.index)
    resource_group_name = azurerm_resource_group.talosrg.name
    allocation_method = "Static"
    location = var.region
  
}

resource "azurerm_public_ip" "talos-public-ip-lb" {
    name = "talos-public-ip-lb"
    resource_group_name = azurerm_resource_group.talosrg.name
    allocation_method = "Static"
    location = var.region
  
}

resource "azurerm_lb" "taloslb" {
    name = "taloslb"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region

    frontend_ip_configuration {
      name = "talosfe"
      public_ip_address_id = azurerm_public_ip.talos-public-ip-lb.id
    }
  
}

#data "azurerm_lb_backend_address_pool" "talosbe" {
#  name            = "talosbe"
#  loadbalancer_id = azurerm_lb.taloslb.id
#}

resource "azurerm_lb_probe" "talos-lb-health" {
  loadbalancer_id = azurerm_lb.taloslb.id
  name            = "talos-lb-health"
  port            = 6443
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "talos-6443" {
  loadbalancer_id                = azurerm_lb.taloslb.id
  name                           = "talos-6443"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "talosfe"
#  backend_address_pool_ids = [ data.azurerm_lb_backend_address_pool.talosbe.id ]
  
  probe_id = azurerm_lb_probe.talos-lb-health.id
}

resource "azurerm_network_interface" "nics" {
  count             = length(var.nics)
  name              = "nic-${count.index}"
  location          = var.region
  resource_group_name = azurerm_resource_group.talosrg.name


  ip_configuration {
    private_ip_address_allocation = "Dynamic"
    name            = "config-${count.index}"
    subnet_id       = azurerm_subnet.talossubnet.id
    private_ip_address = element(var.nics, count.index)
    public_ip_address_id = element(azurerm_public_ip.talos-public-ip[*].id, count.index % 4)
    
  }
}

resource "azurerm_availability_set" "talosas" {
    name = "talosas"
    location = azurerm_resource_group.talosrg.location
    resource_group_name = azurerm_resource_group.talosrg.name


}

resource "null_resource" "createtalosconfig" {
    provisioner "local-exec" {

        command = "talosctl gen config talos-k8s https://${azurerm_public_ip.talos-public-ip-lb.ip_address}:6443 "

  }

  depends_on = [ azurerm_lb.taloslb ]

}

data "local_file" "controllerfile" {
  filename = "./controlplane.yaml"
  depends_on = [ null_resource.createtalosconfig ]
}

data "local_file" "workerfile" {
  filename = "./worker.yaml"
  depends_on = [ null_resource.createtalosconfig ]
}

resource "azurerm_virtual_machine" "talosmaster" {
    count = var.mastercount
    name = "talosmaster"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region
    vm_size = var.instancetype
    boot_diagnostics {
      enabled = true
      storage_uri = azurerm_storage_account.talosimagesa.primary_web_endpoint
    }

    os_profile {
      computer_name  = "talos"
      admin_username = "talos"
      custom_data = data.local_file.controllerfile.content
    }

    storage_data_disk {
      name = "talosstoragedata"
      disk_size_gb = "20"
      lun = "1"
      create_option = "Attach"
    }

    storage_os_disk {
    name              = "talososdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    }

    network_interface_ids = [ element( azurerm_network_interface.nics[*].id, count.index ) ]
    availability_set_id = azurerm_availability_set.talosas.id


  
}

resource "azurerm_virtual_machine" "talosworker" {
    count = var.workercount
    name = "talosworker"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region
    vm_size = var.instancetype
    boot_diagnostics {
      enabled = true
      storage_uri = azurerm_storage_account.talosimagesa.primary_web_endpoint
    }

    os_profile {
      computer_name  = "talos"
      admin_username = "talos"
      custom_data = data.local_file.workerfile.content
    }

    storage_data_disk {
      name = "talosstoragedata"
      disk_size_gb = "20"
      lun = "1"
      create_option = "Attach"
    }
    
    storage_os_disk {
    name              = "talososdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    }
    availability_set_id = azurerm_availability_set.talosas.id
    network_interface_ids = [ element( azurerm_network_interface.nics[*].id, count.index ) ]
    

  
}

resource "null_resource" "bootstrap_etcd" {
    provisioner "local-exec" {
        command = "/bin/bash scripts/bootstrapetcd.sh ${azurerm_lb.taloslb.frontend_ip_configuration[0].public_ip_address_id}"
      
    }
    depends_on = [ azurerm_virtual_machine.talosmaster ]

}

