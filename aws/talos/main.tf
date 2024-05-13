
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
  backend "s3" {
#    bucket         	   = "${var.tfstatebucket}"
    key              	 = "state/terraform.tfstate"
#    region         	   = "${var.tfstatebucketregion}"
    encrypt        	   = true
#    dynamodb_table = "${var.dynamotableid}"
  }
}

#provider "vault" {
#  address = "https://vault-0.default.svc:8200"
#  skip_tls_verify = true
#}
#data "vault_generic_secret" "aws_creds" {
#    path = "aws/aws"
#}

provider "aws" {
    region = var.region
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
#    access_key = data.vault_generic_secret.aws_creds.data["aws_access_key_id"]
#    secret_key = data.vault_generic_secret.aws_creds.data["aws_secret_access_key"]
}

data "aws_ami" "talos"{
    most_recent = true
    name_regex = "^talos-aws-1.3.3*"
    owners = ["894352288813"]

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
  
  version = "8.7.0"

  name = var.albname

  load_balancer_type = "network"

  vpc_id = module.vpc.vpc_id

  subnets = [ "${element(module.vpc.private_subnets, 0)}","${element(module.vpc.private_subnets, 1)}" ]

}


resource "null_resource" "createtalosconfig" {
    provisioner "local-exec" {

        command = "/bin/bash scripts/talosconfiggen.sh -h ${module.alb.lb_dns_name} -p 443 -t ${var.talosctlfolderpath}"

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

resource "aws_placement_group" "talosplacemnentgroup" {
  name     = "talosplacemnentgroup"
  strategy = "cluster"
}

resource "aws_launch_configuration" "talosmaster" {
  name = "talos-master"
  image_id = data.aws_ami.talos.id
  instance_type = var.instance_type
}

resource "aws_lb" "talosapi" {
  name               = "talosapi"
  internal           = false
  load_balancer_type = "network"
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = true

}

resource "aws_autoscaling_group" "talosmaster-static" {
  name                      = "talosmaster-static"
  max_size                  = 20
  min_size                  = var.mastercount
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  placement_group           = aws_placement_group.talosplacemnentgroup.id
  launch_configuration      = aws_launch_configuration.talosmaster.name
  load_balancers = aws_lb.talosapi.arn


  timeouts {
    delete = "15m"
  }

}

resource "aws_autoscaling_group" "talosmaster-scalable" {
  name                      = "talosmaster-scalable"
  max_size                  = 20
  min_size                  = var.mastercount
  health_check_grace_period = 300
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  placement_group           = aws_placement_group.talosplacemnentgroup.id
  launch_configuration      = aws_launch_configuration.talosmaster.name


  timeouts {
    delete = "15m"
  }

}

# resource "aws_instance" talos_master_instance {

#     count = var.mastercount

#     ami = data.aws_ami.talos.id
#     instance_type = var.instance_type
#     monitoring  = var.nodemonitoringenabled
#     vpc_security_group_ids = [ module.security_group.security_group_id ]
#     subnet_id              = "${element(module.vpc.private_subnets, 0)}"

#     user_data = data.local_file.controllerfile.content
#     associate_public_ip_address = true

#     root_block_device {
#        volume_size = 200
#     }

#     depends_on = [ data.local_file.controllerfile ]

#     tags = {
#        Name = "talosmaster"
#     }


# }
# resource "aws_instance" talos_worker_instance {
    
#     count = var.workercount

#     ami = data.aws_ami.talos.id
#     instance_type = var.instance_type
#     monitoring  = var.nodemonitoringenabled
#     vpc_security_group_ids = [ module.security_group.security_group_id ]
#     subnet_id              = "${element(module.vpc.private_subnets, 0)}"

#     user_data = data.local_file.workerfile.content
#     associate_public_ip_address = true

#     depends_on = [ data.local_file.workerfile ]

#     root_block_device {
#        volume_size = 200
#     }
#     tags = {
#        Name = "talosworker"
#     }


# }

# resource "aws_ebs_volume" "ebs_volume" {
#   count             = "${var.workercount}"
#   availability_zone = "${element(aws_instance.talos_master_instance.*.availability_zone, count.index)}"
#   size              = "200"
# }

# resource "aws_volume_attachment" "volume_attachement" {
#   count       = "${var.workercount}"
#   volume_id   = "${aws_ebs_volume.ebs_volume.*.id[count.index]}"
#   device_name = "/dev/sdd"
#   instance_id = "${element(aws_instance.talos_worker_instance.*.id, count.index)}"
# }

resource "aws_lb_target_group" "talos-tg" {
    name = var.talostg
    port = 6443
    protocol = "TCP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
  
}

resource "aws_lb_target_group" "talos-api" {
    name = "talosapi"
    port = 500000
    protocol = "TCP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
  
}

# resource "aws_lb_target_group" "traefik-tg-80" {
#     name = var.traefik_tg_80_name
#     port = var.traefikhttpport
#     protocol = "TCP"
#     target_type = "ip"
#     vpc_id = module.vpc.vpc_id
  
# }

resource "aws_lb_target_group" "traefik-tg-443" {
    name = var.traefik_tg_443_name
    port = var.traefikhttpsport
    protocol = "TCP"
    target_type = "ip"
    vpc_id = module.vpc.vpc_id
  
}

resource "aws_lb_target_group" "nats-tg-4222" {
    name = var.nats_tg_4222_name
    port = var.nats_client_port
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

resource "aws_lb_target_group_attachment" "talosapi" {

    count = var.mastercount
    target_group_arn = aws_lb_target_group.talos-tg.arn
    target_id = "${element(split(",", join(",", aws_instance.talos_master_instance.*.private_ip)), count.index)}" 
    depends_on = [ aws_instance.talos_master_instance ]  

}
# resource "aws_lb_target_group_attachment" "registertarget-traefik-80" {

#     count = var.workercount
#     target_group_arn = aws_lb_target_group.traefik-tg-80.arn
#     target_id = "${element(split(",", join(",", aws_instance.talos_worker_instance.*.private_ip)), count.index)}" 
#     depends_on = [ aws_instance.talos_worker_instance ]  

# }

resource "aws_lb_target_group_attachment" "registertarget-traefik-443" {

    count = var.workercount
    target_group_arn = aws_lb_target_group.traefik-tg-443.arn
    target_id = "${element(split(",", join(",", aws_instance.talos_worker_instance.*.private_ip)), count.index)}" 
    depends_on = [ aws_instance.talos_worker_instance ]  

}

resource "aws_lb_target_group_attachment" "registertarget-nats-4222" {

    count = var.mastercount
    target_group_arn = aws_lb_target_group.nats-tg-4222.arn
    target_id = "${element(split(",", join(",", aws_instance.talos_worker_instance.*.private_ip)), count.index)}" 
    depends_on = [ aws_instance.talos_worker_instance ]  

}

resource "aws_eip" "traefik" {
  vpc      = true
}

resource "aws_lb" "traefik" {
  name               = var.traefiklbname
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = "${element(module.vpc.private_subnets, 0)}"
    allocation_id = aws_eip.traefik.id
  }

  subnet_mapping {
    subnet_id     = "${element(module.vpc.private_subnets, 1)}"
    allocation_id = aws_eip.traefik.id
  }
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

resource "aws_alb_listener" "traefik-listener-443" {
    load_balancer_arn = aws_lb.traefik.arn
    port = 443
    protocol = "TCP"
    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.traefik-tg-443.arn
  }
  
}
 
resource "aws_alb_listener" "nats-listener-4222" {
    load_balancer_arn = aws_lb.traefik.arn
    port = 4222
    protocol = "TCP"
    default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nats-tg-4222.arn
  }
  
}


resource "null_resource" "bootstrap_etcd" {
    provisioner "local-exec" {
        command = "${var.talosctlfolderpath}/talosctl  --talosconfig scripts/talosconfig config endpoint ${aws_instance.talos_master_instance.0.public_ip}"
      
    }
    provisioner "local-exec" {
        command = "/${var.talosctlfolderpath}/talosctl  --talosconfig scripts/talosconfig config node ${aws_instance.talos_master_instance.0.public_ip}"

    }
    provisioner "local-exec" {
        command = "sleep 60; ${var.talosctlfolderpath}/talosctl --talosconfig scripts/talosconfig bootstrap"
    }

    provisioner "local-exec" {
        command = "${var.talosctlfolderpath}/talosctl --talosconfig scripts/talosconfig kubeconfig ${var.configfolderpath}"
    }
    
    provisioner "local-exec" {
        command = "echo 'LoadBalancerHost: \"${aws_lb.traefik.dns_name}\"' > ${var.configfolderpath}/capten-lb-endpoint.yaml"
    }
    depends_on = [ aws_instance.talos_master_instance ]

}
