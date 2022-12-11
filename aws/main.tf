provider "aws" {
    region = var.region
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
}

data "aws_ami" "talos"{
    most_recent = true
    name_regex = "^talos-v1.1.1*"
    owners = ["540036508848"]

    filter {
        name = "architecture"
        values = ["x86_64"]
    }

}


module "vpc" {
    source  = "terraform-aws-modules/vpc/aws"

    name = var.vpcname
    cidr = var.vpccidr

    azs = ["${var.region}a", "${var.region}b", "${var.region}c"]
    private_subnets = [ var.privatesubnet ]
    create_igw = true
}

resource "aws_internet_gateway" "ig" {
  vpc_id = "${module.vpc.vpc_id}"
  tags = {
    Name        = "${var.vpcname}-igw"
  }
} 

resource "aws_route" "igwroute" {
  route_table_id = module.vpc.vpc_main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

resource "aws_route" "privateigwroute" {
  route_table_id = module.vpc.private_route_table_ids[0]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.ig.id
}

module "security_group" {
    source  = "terraform-aws-modules/security-group/aws"

    name = var.securitygroupname
    description = "Security group for VPC"
    vpc_id = module.vpc.vpc_id


    ingress_cidr_blocks = ["0.0.0.0/0"]
    ingress_rules       = ["http-80-tcp", "all-all"]
    
    egress_rules        = ["all-all"]

}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"

  name = var.albname

  load_balancer_type = "network"

  vpc_id = module.vpc.vpc_id

  subnets = [ "${element(module.vpc.private_subnets, 0)}","${element(module.vpc.private_subnets, 1)}" ]

}


resource "null_resource" "createtalosconfig" {
    provisioner "local-exec" {

        command = "/bin/bash scripts/talosconfiggen.sh -h ${module.alb.lb_dns_name} -p 443"

  }

  depends_on = [ module.alb ]

}

data "local_file" "controllerfile" {
  filename = "scripts/controlplane.yaml"
  depends_on = [ null_resource.createtalosconfig ]
}

data "local_file" "workerfile" {
  filename = "scripts/worker.yaml"
  depends_on = [ null_resource.createtalosconfig ]
}

resource "aws_instance" talos_master_instance {

    count = var.mastercount

    ami = data.aws_ami.talos.id
    instance_type = var.instance_type
    monitoring  = var.nodemonitoringenabled
    vpc_security_group_ids = [ module.security_group.security_group_id ]
    subnet_id              = "${element(module.vpc.private_subnets, 0)}"

    user_data = data.local_file.controllerfile.content
    associate_public_ip_address = true

    depends_on = [ data.local_file.controllerfile ]

    tags = {
       Name = "talosmaster"
    }


}
resource "aws_instance" talos_worker_instance {
    
    count = var.workercount

    ami = data.aws_ami.talos.id
    instance_type = var.instance_type
    monitoring  = var.nodemonitoringenabled
    vpc_security_group_ids = [ module.security_group.security_group_id ]
    subnet_id              = "${element(module.vpc.private_subnets, 0)}"

    user_data = data.local_file.workerfile.content
    associate_public_ip_address = true

    depends_on = [ data.local_file.workerfile ]

    tags = {
       Name = "talosworker"
    }


}


resource "aws_lb_target_group" "talos-tg" {
    name = "talos-tg"
    port = 6443
    protocol = "TCP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
  
}

resource "aws_lb_target_group_attachment" "registertarget" {

    count = var.mastercount
    target_group_arn = aws_lb_target_group.talos-tg.arn
    target_id = "${element(split(",", join(",", aws_instance.talos_master_instance.*.private_ip)), count.index)}" 
    depends_on = [ aws_instance.talos_master_instance ]  

}


resource "aws_alb_listener" "talos-listener" {
    load_balancer_arn = module.alb.lb_arn
    port = 443
    protocol = "TCP"
    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.talos-tg.arn
  }
  
}

resource "null_resource" "bootstrap_etcd" {
    provisioner "local-exec" {
        command = "talosctl  --talosconfig scripts/talosconfig config endpoint ${aws_instance.talos_master_instance.0.public_ip}"
      
    }
    provisioner "local-exec" {
        command = "talosctl  --talosconfig scripts/talosconfig config node ${aws_instance.talos_master_instance.0.public_ip}"

    }
    provisioner "local-exec" {
        command = "sleep 60; talosctl --talosconfig scripts/talosconfig bootstrap"
    }

    provisioner "local-exec" {
        command = "talosctl --talosconfig scripts/talosconfig kubeconfig ."
    }
    depends_on = [ aws_instance.talos_master_instance ]

}
