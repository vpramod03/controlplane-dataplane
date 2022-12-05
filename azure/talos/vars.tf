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
