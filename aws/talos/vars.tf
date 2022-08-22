variable "AWS_ACCESS_KEY" {
  description = "AWS Access key"
}

variable "AWS_SECRET_KEY" {
  description = "AWS Secret key"
}

variable "region" {
  description = "AWS Region to deploy the resources"
}

variable "privatesubnet" {
  description = "vpc private subnet cidr"
}

variable "vpcname" {
  description = "Name of the VPC to be created"
}

variable "vpccidr" {
    description = "VPC cidr to be used while creating VPC"
}

variable "securitygroupname" {
    description = "Security group name to be created "
  
}

variable "albname" {
    description = "AWS loadbalancer name"
  
}

variable "instance_type" {
    description = "aws instance type to be used"
}

variable "nodemonitoringenabled" {
    description = "aws monitoring enabled/disabled mark true/false"
}

variable "mastercount" {
    description = "talos master node count"
}

variable "workercount" {
    description = "talos worker node count"
}

