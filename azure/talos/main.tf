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
  name     = var.storagergname
  location = var.region
}    

resource "azurerm_storage_account" "talosimagesa" {
  name                     = var.storage_account_name
  resource_group_name      = "${azurerm_resource_group.storagerg.name}"
  location                 = var.region
  account_tier             = "Standard"
  account_replication_type = "GRS"

  tags = {
    environment = "talosaz"
  }
}


resource "azurerm_storage_container" "talosimagecont" {
  name                  = var.talos_imagecont_name
  storage_account_name  = azurerm_storage_account.talosimagesa.name
  container_access_type = "private"
}

#resource "null_resource" "talosimagecreate" {

#    provisioner "local-exec" {
#        command = "/bin/bash scripts/talos-image-gen.sh"
#    }
#    depends_on = [
#      azurerm_storage_container.talosimagecont
#    ]
#}

#resource "azurerm_storage_blob" "talosimageblob" {
#  name = "talosimageblob"
#  storage_account_name = azurerm_storage_account.talosimagesa.name
#  storage_container_name = azurerm_storage_container.talosimagecont.name
#  source = "manifests/image/talos/azure-amd64.vhd"
#  type = "Block"

#}

#resource "azurerm_image" "talosimage" {
#  name                      = "talos-azure"
#  location                  = var.region
#  resource_group_name       = azurerm_resource_group.storagerg.name
#  
#  os_disk {
#    os_type = "Linux"
#    os_state = "Generalized"
#    blob_uri = "https://${azurerm_storage_account.talosimagesa.name}.blob.core.windows.net/${azurerm_storage_container.talosimagecont.name}/talos-azure.vhd"
#  }
#  depends_on = [ null_resource.talosimagecreate ]
#}

resource "azurerm_resource_group" "talosrg" {
  name     = var.talosrgname
  location = var.region
}  

resource "azurerm_virtual_network" "talosnet" {
    name = "${var.talos_cluster_name}-vnet"
    address_space = [ "10.0.0.0/16" ]
    location = var.region
    resource_group_name = azurerm_resource_group.talosrg.name
  
}

resource "azurerm_subnet" "talossubnet" {
    name = "${var.talos_cluster_name}-subnet"
    resource_group_name = azurerm_resource_group.talosrg.name
    virtual_network_name = azurerm_virtual_network.talosnet.name
    address_prefixes = [ "10.0.1.0/24" ]
  
}

resource "azurerm_network_security_group" "talossg" {
    name = "${var.talos_cluster_name}-talossg"
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

resource "azurerm_network_security_rule" "traefikhttps" {
    name = "kube"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1005"
    source_port_range = "*"
    destination_port_ranges = [ "${var.traefikhttpsport}" ]
    source_address_prefix  = "*"
    destination_address_prefix  = "*"
    direction = "Inbound"
    access = "Allow"
    resource_group_name = azurerm_resource_group.talosrg.name
    protocol = "Tcp"

}

resource "azurerm_network_security_rule" "traefikhttp" {
    name = "kube"
    network_security_group_name = azurerm_network_security_group.talossg.name
    priority = "1006"
    source_port_range = "*"
    destination_port_ranges = [ "${var.traefikhttpport}" ]
    source_address_prefix  = "*"
    destination_address_prefix  = "*"
    direction = "Inbound"
    access = "Allow"
    resource_group_name = azurerm_resource_group.talosrg.name
    protocol = "Tcp"

}

resource "azurerm_public_ip" "talos-public-ip" {
    count = length(var.publicipname)
    name = "${var.talos_cluster_name}-publicip-${count.index}"
    resource_group_name = azurerm_resource_group.talosrg.name
    allocation_method = "Static"
    location = var.region
    sku = "Standard"
  
}

resource "azurerm_public_ip" "talos-public-ip-lb" {
    name = "${var.talos_cluster_name}-talos-public-ip-lb"
    resource_group_name = azurerm_resource_group.talosrg.name
    allocation_method = "Static"
    location = var.region
    sku = "Standard"
  
}

resource "azurerm_public_ip" "talos-public-ip-nat" {
    name = "${var.talos_cluster_name}-talos-public-ip-nat"
    resource_group_name = azurerm_resource_group.talosrg.name
    allocation_method = "Static"
    location = var.region
    sku = "Standard"
  
}

resource "azurerm_public_ip" "talos-public-ip-traefik" {
    name = "${var.talos_cluster_name}-talos-public-ip-traefik"
    resource_group_name = azurerm_resource_group.talosrg.name
    allocation_method = "Static"
    location = var.region
    sku = "Standard"
  
}

resource "azurerm_lb" "taloslb" {
    name = "${var.talos_cluster_name}-lb"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region
    sku = "Standard"

    frontend_ip_configuration {
      name = "${var.talos_cluster_name}-talosfe"
      public_ip_address_id = azurerm_public_ip.talos-public-ip-lb.id
    }
  
}

resource "azurerm_lb" "traefiklb" {
    name = "${var.talos_cluster_name}-traefiklb"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region
    sku = "Standard"

    frontend_ip_configuration {
      name = "${var.talos_cluster_name}-traefikfe"
      public_ip_address_id = azurerm_public_ip.talos-public-ip-traefik.id
    }
  
}

resource "azurerm_lb_backend_address_pool" "talosbe" {
  name            = "${var.talos_cluster_name}-talosbe"
  loadbalancer_id = azurerm_lb.taloslb.id
  depends_on = [ azurerm_lb.taloslb ]
}

resource "azurerm_lb_backend_address_pool" "traefikbe" {
  name            = "${var.talos_cluster_name}-traefikbe"
  loadbalancer_id = azurerm_lb.traefiklb.id
  depends_on = [ azurerm_lb.traefiklb ]
}

resource "azurerm_network_interface_backend_address_pool_association" "lbbackendassociation" {
  count = length(var.nics)
  network_interface_id = element( azurerm_network_interface.nics[*].id, count.index % 4)
  ip_configuration_name = "${var.talos_cluster_name}-config-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.talosbe.id
  
}

resource "azurerm_network_interface_backend_address_pool_association" "traefikbeassociation" {
  count = length(var.workernics)
  network_interface_id = element( azurerm_network_interface.workernics[*].id, count.index % 4)
  ip_configuration_name = "${var.talos_cluster_name}-workerconfig-${count.index}"
  backend_address_pool_id = azurerm_lb_backend_address_pool.traefikbe.id
  
}

resource "azurerm_lb_probe" "talos-lb-health" {
  loadbalancer_id = azurerm_lb.taloslb.id
  name            = "talos-lb-health"
  port            = 6443
  protocol        = "Tcp"
}

resource "azurerm_lb_probe" "traefik-443-health" {
  loadbalancer_id = azurerm_lb.traefiklb.id
  name            = "traefik-443-health"
  port            = 443
  protocol        = "Tcp"
}

resource "azurerm_lb_probe" "traefik-80-health" {
  loadbalancer_id = azurerm_lb.traefiklb.id
  name            = "traefik-80-health"
  port            = 80
  protocol        = "Tcp"
}

resource "azurerm_lb_probe" "nats-4222-health" {
  loadbalancer_id = azurerm_lb.traefiklb.id
  name            = "nats-4222-health"
  port            = 4222
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "talos-6443" {
  loadbalancer_id                = azurerm_lb.taloslb.id
  name                           = "talos-6443"
  protocol                       = "Tcp"
  frontend_port                  = 6443
  backend_port                   = 6443
  frontend_ip_configuration_name = "${var.talos_cluster_name}-talosfe"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.talosbe.id ]
  
  probe_id = azurerm_lb_probe.talos-lb-health.id
}

resource "azurerm_lb_rule" "traefik-443" {
  loadbalancer_id                = azurerm_lb.traefiklb.id
  name                           = "traefik-443"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = var.traefikhttpsport
  frontend_ip_configuration_name = "${var.talos_cluster_name}-traefikfe"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.traefikbe.id ]
  
  probe_id = azurerm_lb_probe.traefik-443-health.id
}

resource "azurerm_lb_rule" "traefik-80" {
  loadbalancer_id                = azurerm_lb.traefiklb.id
  name                           = "traefik-80"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = var.traefikhttpport
  frontend_ip_configuration_name = "${var.talos_cluster_name}-traefikfe"
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.traefikbe.id ]
  
  probe_id = azurerm_lb_probe.traefik-80-health.id
}

resource "azurerm_lb_rule" "nats-4222" {
  loadbalancer_id                = azurerm_lb.traefiklb.id
  name                           = "nats-4222"
  protocol                       = "Tcp"
  frontend_port                  = 4222
  backend_port                   = var.nats-client-port
  frontend_ip_configuration_name = "traefikfe "
  backend_address_pool_ids = [ azurerm_lb_backend_address_pool.traefikbe.id ]
  
  probe_id = azurerm_lb_probe.nats-4222-health.id
}

resource "azurerm_network_interface" "nics" {
  count             = length(var.nics)
  name              = "${var.talos_cluster_name}-nic-${count.index}"
  location          = var.region
  resource_group_name = azurerm_resource_group.talosrg.name


  ip_configuration {
    private_ip_address_allocation = "Dynamic"
    name            = "${var.talos_cluster_name}-config-${count.index}"
    subnet_id       = azurerm_subnet.talossubnet.id
    private_ip_address = element(var.nics, count.index)
    public_ip_address_id = element(azurerm_public_ip.talos-public-ip[*].id, count.index % 4)
    
  }
}

resource "azurerm_network_interface" "workernics" {
  count             = length(var.workernics)
  name              = "${var.talos_cluster_name}-workernic-${count.index}"
  location          = var.region
  resource_group_name = azurerm_resource_group.talosrg.name


  ip_configuration {
    private_ip_address_allocation = "Dynamic"
    name            = "${var.talos_cluster_name}-workerconfig-${count.index}"
    subnet_id       = azurerm_subnet.talossubnet.id
    private_ip_address = element(var.nics, count.index)
    
  }
}

resource "azurerm_availability_set" "talosas" {
    name = "${var.talos_cluster_name}-talosas"
    location = azurerm_resource_group.talosrg.location
    resource_group_name = azurerm_resource_group.talosrg.name
    managed = true

}

resource "azurerm_network_interface_security_group_association" "networkinterface_sg_association" {
  count = length(var.workernics)
  network_interface_id = element( azurerm_network_interface.nics[*].id, count.index % 4)
  network_security_group_id = azurerm_network_security_group.talossg.id
}

resource "azurerm_network_interface_security_group_association" "networkinterface_worker_sg_association" {
  count = length(var.workernics)
  network_interface_id = element( azurerm_network_interface.workernics[*].id, count.index % 4)
  network_security_group_id = azurerm_network_security_group.talossg.id
}

resource "azurerm_nat_gateway" "talosnat" {
  name                = "${var.talos_cluster_name}-worker-node-nat"
  location            = var.region
  resource_group_name = azurerm_resource_group.talosrg.name
}

resource "azurerm_subnet_nat_gateway_association" "talosnatassocation" {
  subnet_id      = azurerm_subnet.talossubnet.id
  nat_gateway_id = azurerm_nat_gateway.talosnat.id
}

resource "azurerm_nat_gateway_public_ip_association" "publicipnatassociation" {
  nat_gateway_id       = azurerm_nat_gateway.talosnat.id
  public_ip_address_id = azurerm_public_ip.talos-public-ip-nat.id
}

resource "null_resource" "createtalosconfig" {
    provisioner "local-exec" {

        command = "/bin/bash scripts/talosconfiggen.sh -h ${azurerm_public_ip.talos-public-ip-lb.ip_address} -p 6443 -t ${var.talosctlfolderpath}"

  }

  depends_on = [ azurerm_lb.taloslb ]

}

data "local_file" "controllerfile" {
  filename = "scripts/controlplane.yaml"
  depends_on = [ null_resource.createtalosconfig ]
}

data "local_file" "workerfile" {
  filename = "scripts/worker.yaml"
  depends_on = [ null_resource.createtalosconfig ]
}

resource "azurerm_virtual_machine" "talosmaster" {
    count = length(var.mastercount)
    name = "${var.talos_cluster_name}-talosmaster-${count.index}"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region
    vm_size = var.instancetype
    boot_diagnostics {
      enabled = true
      storage_uri = "https://${azurerm_storage_account.talosimagesa.name}.blob.core.windows.net"
    }

    os_profile {
      computer_name  = "${var.talos_cluster_name}-talosmaster-${count.index}"
      admin_username = "talos"
      admin_password = "Talos@1234"
      custom_data = data.local_file.controllerfile.content
    }

#    storage_data_disk {
#      name = "talosstoragedata"
#      disk_size_gb = "20"
#      lun = "1"
#      create_option = "Empty"
#    }

    storage_image_reference {
      id = "/subscriptions/7bccafd3-c548-4b45-837d-fb7dc81167b6/resourceGroups/talos-image/providers/Microsoft.Compute/images/talos"
    }
    storage_os_disk {
    name              = "${var.talos_cluster_name}-talosmaster-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb = "20"
    }

    os_profile_linux_config {
    disable_password_authentication = false
    }

    network_interface_ids = [ element( azurerm_network_interface.nics[*].id, count.index ) ]
    availability_set_id = azurerm_availability_set.talosas.id
    delete_os_disk_on_termination = true

    depends_on = [ azurerm_availability_set.talosas ]


  
}

resource "azurerm_virtual_machine" "talosworker" {
    count = length(var.workercount)
    name = "${var.talos_cluster_name}-talosworker-${count.index}"
    resource_group_name = azurerm_resource_group.talosrg.name
    location = var.region
    vm_size = var.instancetype

    boot_diagnostics {
      enabled = true
      storage_uri = "https://${azurerm_storage_account.talosimagesa.name}.blob.core.windows.net"
    }
    
    os_profile {
      computer_name  = "${var.talos_cluster_name}-talosworker-${count.index}"
      admin_username = "talos"
      admin_password = "Talos@1234"
      custom_data = data.local_file.workerfile.content
    }

   storage_data_disk {
      name = "datadisk-talosworker${count.index}"
      disk_size_gb = "200"
      lun = "1"
      create_option = "Empty"
    }
    storage_image_reference {
      id = "/subscriptions/7bccafd3-c548-4b45-837d-fb7dc81167b6/resourceGroups/talos-image/providers/Microsoft.Compute/images/talos"
    }

    storage_os_disk {
    name              = "${var.talos_cluster_name}-talosworker-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
    disk_size_gb = "20"
    }
    availability_set_id = azurerm_availability_set.talosas.id
    network_interface_ids = [ element(azurerm_network_interface.workernics[*].id, count.index ) ]

    os_profile_linux_config {
    disable_password_authentication = false
    }
    delete_os_disk_on_termination = true
    
    depends_on = [ azurerm_availability_set.talosas ]
  
}


resource "null_resource" "bootstrap_etcd" {
    provisioner "local-exec" {
        command = "/bin/bash scripts/bootstrapetcd.sh ${azurerm_public_ip.talos-public-ip[0].ip_address} ${var.talosctlfolderpath}"
      
    }
    provisioner "local-exec" {
        command = "${var.talosctlfolderpath}/talosctl --talosconfig scripts/talosconfig kubeconfig ${var.configfolderpath} --nodes ${azurerm_public_ip.talos-public-ip[0].ip_address}"
      
    }
    provisioner "local-exec" {
        command = "echo 'LoadBalancerHost: \"${azurerm_public_ip.talos-public-ip-traefik.ip_address}\"' > ${var.configfolderpath}/capten-lb-endpoint.yaml"
    } 
    depends_on = [ azurerm_virtual_machine.talosmaster  ]

}

