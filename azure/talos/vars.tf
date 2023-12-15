variable "region" {
  description = "Azure Region to deploy the resources"
}

variable "mastercount" {
    description = "talos master node count"
    default = 3
}

variable "workercount" {
    description = "talos worker node count"
    default = 3
}

variable "nics" {
    description = "nics name"
}

variable "workernics" {
    description = "nics name"
}

variable "instancetype" {
    description = "instancetype of virtual machines"
}

variable "publicipname" {
    type = list
    description = "public ip name"
}

variable "traefikhttpport" {
    description = "Name of the traefik 80 port target group"
}

variable "nats_client_port" {
    description = "Name of the nats-client-port 4222 port target group"
}


variable "traefikhttpsport" {
    description = "Name of the traefik 443 port target group"
}

variable "configfolderpath" {
    description = "CLI config folder path"
}

variable "talosctlfolderpath" {
    description = "home folder path for capten cli dir"  
}

variable "talosrgname" {
    description = "talos resourcegroup name"
}

variable "storagergname" {
    description = "storage resourcegroup name"
}

variable "storage_account_name" {
    description = "stoarge accountname for talosimage and diagnostics"
}

variable "talos_imagecont_name" {
    description = "talosimage container name"
}

variable "talos_cluster_name" {
    description = "talosvnet name"
}
