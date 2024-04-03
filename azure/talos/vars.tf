variable "region" {
  description = "Azure Region to deploy the resources"
}

variable "staticmasternodecount" {
    description = "talos master node count"
    default = 3
}

variable "staticworkernodecount" {
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

variable "wokerscalesetname" {
    description = "talosworkerscaleset name"
}

variable "masterstaticname" {
    description = "talos master static name"
}

variable "workerstaticname" {
    description = "talos worker static name"
}

variable "masterscalesetname" {
    description = "talos master scaleset name"
}

variable "subscription_id" {
    description = "subscription id"
}

variable "tfstatergname" {
    description = "resourcegroup where tfstate to be stored"  
}

variable "tfstatesaname" {
    description = "storage account name of tfstate"
  
}

variable "tfstatecontname" {
    description = "tfstate storage account container name"
}