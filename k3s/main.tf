#Initialization of Provider
provider "aws" {
    region = var.region
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
}

#Initially taking amazon linux ami kernel
data "aws_ami" "amazonlinux"{
    most_recent = true
    name_regex = "^Amazon Linux 2 Kernel 5.10 *"
    owners = ["ami-06489866022e12a14"]

    filter {
        name = "architecture"
        values = ["x86_64"]
    }

}

#Server initialization script to be run on ec2 bringup
data "template_cloudinit_config" "server" {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/server_install.sh", {
      k3s_token                 = var.k3s_token,
      is_k3s_server             = true,
      k3s_url                   = aws_lb.k3s_server.dns_name,
      k3s_tls_san               = aws_lb.k3s_server.dns_name
    })
  
}


#Worker initialization script 
data "template_cloudinit_config" "worker" {
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/scripts/worker_install.sh", {
      k3s_token                 = var.k3s_token,
      is_k3s_server             = false,
      k3s_url                   = aws_lb.k3s_worker.dns_name,
      k3s_tls_san               = aws_lb.k3s_worker.dns_name
    })
  
}

#Creating VPC with multiple availability zones
module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"

    name = var.vpcname
    cidr = var.vpccidr

    azs = ["${var.region}a", "${var.region}b", "${var.region}c"]
    private_subnets = [ var.privatesubnet ]
    create_igw = true
}

#AWS internet gateway creation for ec2 instance to connect to internet to get binaries
resource "aws_internet_gateway" "ig" {
  vpc_id = module.vpc.vpc_id
  tags = {
    Name        = "${var.vpcname}-igw"
  }
} 

#Adding internet gateway to the main routing table
resource "aws_route" "igwroute" {
  route_table_id = module.vpc.vpc_main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

##Adding internet gateway to the VPC routing table
resource "aws_route" "privateigwroute" {
  route_table_id = module.vpc.private_route_table_ids[0]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}


#Create Security group to restrict only some ports (here 6443 mainly for apiserver)
module "security_group" {
    source  = "terraform-aws-modules/security-group/aws"

    name = var.securitygroupname
    description = "Security group for VPC"
    vpc_id = module.vpc.vpc_id


    ingress_cidr_blocks = ["0.0.0.0/0"]
    ingress_rules       = [ "k8s-apiserver" ]

    rules = { "k8s-apiserver" : [ 6443 , 6443 , "tcp" , "Apiserver" ] , "all-all": [ -1, -1, "icmp", "All protocols" ]}

    egress_rules        = ["all-all"]

}


#Creating aws server loadbalancer 
resource "aws_lb" "k3s_server" {
    name = "k3s_server_lb"
    internal           = false
    load_balancer_type = "application"
    security_groups = [ module.security_group.security_group_id ]
    subnets = [ element(module.vpc.private_subnets, 0) ]
  
}

#creating aws worker loadbalancer
resource "aws_lb" "k3s_worker" {
    name = "k3s_worker_lb"
    internal           = false
    load_balancer_type = "application"
    security_groups = [ module.security_group.security_group_id ]
    subnets = [ element(module.vpc.private_subnets, 0) ]
  
}


#Initializing k3s master instances
resource "aws_instance" k3s_master_instance {

    count = var.mastercount

    ami = data.aws_ami.amazonlinux.id
    instance_type = var.instance_type
    monitoring  = var.nodemonitoringenabled
    vpc_security_group_ids = [ module.security_group.security_group_id ]
    subnet_id              = element(module.vpc.private_subnets, 0)

    user_data = data.template_cloudinit_config.server.rendered
    associate_public_ip_address = true

    metadata_options {
       http_tokens = "required"
    }

    tags = {
       Name = "k3s-server"
    }


}

#Initializing k3s worker instances
resource "aws_instance" k3s_worker_instance {
    
    count = var.workercount

    ami = data.aws_ami.amazonlinux.id
    instance_type = var.instance_type
    monitoring  = var.nodemonitoringenabled
    vpc_security_group_ids = [ module.security_group.security_group_id ]
    subnet_id              = element(module.vpc.private_subnets, 0)

    user_data = data.template_cloudinit_config.worker.rendered
    associate_public_ip_address = false

    metadata_options {
       http_tokens = "required"
    }

    tags = {
       Name = "k3s-worker"
    }


}

#Creating target group for apiserver
resource "aws_lb_target_group" "k3s-tg" {
    name = "k3s-tg"
    port = 6443
    protocol = "TCP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
  
}

#Attaching instances to the target group
resource "aws_lb_target_group_attachment" "registertarget" {

    count = var.mastercount
    target_group_arn = aws_lb_target_group.k3s-tg.arn
    target_id = element(split(",", join(",", aws_instance.k3s_master_instance.*.private_ip)), count.index)
    depends_on = [ aws_instance.k3s_master_instance ]  

}

#creating LB listener on 443 Port
resource "aws_alb_listener" "k3s-listener" {
    load_balancer_arn = module.alb.lb_arn
    port = 443
    protocol = "HTTPS"
    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.k3s-tg.arn
  }
  
}
