# K3s on AWS

## Introduction
This is a SaaS Solution which installs k3s based on inputs on top of aws. 

## Architecture

![alt text](aws-k3s-arch.PNG "architecture")

## Description

This terraform module creates secure k3s based kubernetes cluster on top of AWS. It Creates the following resources on top of AWS.

### Created Resources
1. VPC
2. Subnets
3. Security Groups
4. Elastic LoadBalancer
5. Internet Gateway
6. Target Groups
7. k3s Based EC2 Instances as specified

### Outputs

The module will output the respective resource id's of the created resources of the cluster.

## Installing

### Prerequisites

1. Windows/Linux system with internet connectivity
2. Active AWS account with secret and access key
3. Terraform cli installed

### Installation

Fill the values.tfvars file inside aws/k3s folder accordingly.

|Values |Description  |
--- | --- |
|AWS_ACCESS_KEY | Access key of the AWS account thats used for installation |
|AWS_SECRET_KEY | Secret key of the AWS account thats used for installation |
|albname | Name of the Application LoadBalancer to be Created |
|privatesubnet | Private Subnet cidr to be used for VPC |
|region | AWS account region where all the resources needs to be created |
|securitygroupname | Name of the Security group to be Created |
|vpccidr | cidr range of vpc should be one from privatesubnet range |
|vpcname |  VPC Name to be created |
|instance_type | Type of EC2 instance to be used for creation. Define this based on the number of resources you run on the cluster|
|nodemonitoringenabled | Define if the nodemonitoring to be enabled for EC2 this could incur significant charges|
|mastercount | Number of master nodes to be created|
|workercount | Number of worker nodes to be created|

### Run the following commands after filling the values.tfvars

``` terraform init ```

This initializes all the modules

``` terraform plan -var-file values.tfvars ```

This will output all the changes that will be done to the AWS resources and also what will be added/removed/modified.

Finally if everything is fine

``` terraform apply -var-files values.tfvars ```

Type yes when prompted.

where main.tf calls the scripts server_install.sh and worker_install.sh inorder to install the k3s on control-plane and worker nodes respectively.

Once the installation is completed the terraform will print success message with number of resources added/modified/destroyed. And all output of the resource id's will be printed.
