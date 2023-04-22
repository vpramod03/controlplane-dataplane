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
  resource_group_name      = "${azurerm_resource_group.testrg.name}"
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags {
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
    address_prefixes = "10.0.1.0/24"
  
}

resource "azurerm_network_security_group" "talossg" {
    name = "talossg"
    resource_group_name = azurerm_resource_group.talosrg.name
  
}

resource "azurerm_network_security_rule" "apid" {
    name = "apid"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1001"
    destination_port_ranges = [ "50000" ]
    direction = "inbound"

}

resource "azurerm_network_security_rule" "trustd" {
    name = "trustd"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1002"
    destination_port_ranges = [ "50001" ]
    direction = "inbound"

}

resource "azurerm_network_security_rule" "etcd" {
    name = "etcd"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1003"
    destination_port_ranges = [ "2379-2380" ]
    direction = "inbound"

}

resource "azurerm_network_security_rule" "kube" {
    name = "kube"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1004"
    destination_port_ranges = [ "6443" ]
    direction = "inbound"

}

resource "azurerm_public_ip" "talos-public-ip" {
    name = "talos-public-ip"
    resource_group_name = azurerm_network_security_group.talossg.name
    allocation_method = "static"
  
}

resource "azurerm_lb" "taloslb" {
    name = "taloslb"
    resource_group_name = azurerm_network_security_group.talossg.name
    location = var.region

    frontend_ip_configuration {
      name = "talosfe"
      public_ip_address_id = azurerm_public_ip.talos-public-ip.id
    }
  
}

data "azurerm_lb_backend_address_pool" "talosbe" {
  name            = "talosbe"
  loadbalancer_id = azurerm_lb.taloslb.id
}

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
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.talosbe.ID ]
  probe_id = azurerm_lb_probe.talos-lb-health.id
  resource_group_name = azurerm_resource_group.talosrg.name

}

resource "azurerm_network_interface" "nics" {
  count             = length(var.nics)
  name              = "nic-${count.index}"
  location          = azurerm_resource_group.group.location
  resource_group_name = azurerm_resource_group.group.name
  network_security_group_name = azurerm_network_security_group.talossg.name
  loadbalancer_id = azurerm_lb.taloslb.ID
  virtual_network_name = azurerm_virtual_network.talosnet.name

  ip_configuration {
    name            = "config-${count.index}"
    subnet_id       = element(azurerm_subnet.subnets[*].id, count.index % 4)
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

        command = "/bin/bash talosctl gen config talos-k8s-azure-tutorial https://${azurerm_lb.taloslb.public_ip}:6443 "

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
    image = "talos"
    resource_group_name = azurerm_resource_group.talosrg.name
    boot_diagnostics {
      storage_uri = azurerm_storage_account.talosimagesa.primary_web_endpoint
    }

    os_profile {
      admin_username = "talos"
      custom_data = data.local_file.controllerfile
    }

    storage_data_disk {
      disk_size_gb = "20"
    }

    network_interface_ids = [ element( azurerm_network_interface.nics[*].ID, count.index ) ]
    availability_set_id = azurerm_availability_set.talosas.id


  
}

resource "azurerm_virtual_machine" "talosworker" {
    count = var.workercount
    name = "talosworker"
    image = "talos"
    resource_group_name = azurerm_resource_group.talosrg.name
    boot_diagnostics {
      storage_uri = azurerm_storage_account.talosimagesa.primary_web_endpoint
    }

    os_profile {
      admin_username = "talos"
      custom_data = data.local_file.workerfile
    }

    storage_data_disk {
      disk_size_gb = "20"
    }

    availability_set_id = azurerm_availability_set.talosas.id
    

  
}

resource "null_resource" "bootstrap_etcd" {
    provisioner "local-exec" {
        command = "/bin/bash scripts/bootstrapetcd.sh ${azurerm_virtual_machine.talosmaster.0.public_ip}"
      
    }
    depends_on = [ azurerm_virtual_machine.talosmaster ]

}

