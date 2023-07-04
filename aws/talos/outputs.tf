output "ami_name" {
  value = data.aws_ami.talos.id
  description = "AMI used for talos installation"
  
}

output "vpc_id" {
  value = module.vpc.vpc_id
  description = "ID of the VPC created"
}

output "private_route_table_ids" {
  value = module.vpc.public_route_table_ids
  description = "ID of the private route tables created"
}

output "igw_id" {
  value = aws_internet_gateway.ig.id
  description = "ID of the Internet gateway created"
}

output "security_group_id" {
  value = module.security_group.security_group_id
  description = "ID of the Security group Created"
  
}

output "aws_lb_target_group_name" {
  value = module.alb.target_group_names
  description = "List of target groups created"

}

output "alb_id" {
  value = module.alb.lb_id
  description = "ID of the alb created"
  
}

output "master_instance_ids" {
  value = aws_spot_instance_request.talos_master_instance.*.host_id
  description = "instance id's of talos master nodes"
  
}

output "master_instance_private_ips" {
  value = aws_spot_instance_request.talos_master_instance.*.private_ip
  description = "List of private ip's of master nodes"
}

output "master_tags" {
  value = aws_spot_instance_request.talos_master_instance.*.tags_all
  description = "All tags that are tagged for worker"
  
}

output "worker_instance_ids" {
  value = aws_spot_instance_request.talos_worker_instance.*.host_id
  description = "instance id's of talos worker nodes"
  
}

output "worker_instance_private_ips" {
  value = aws_spot_instance_request.talos_worker_instance.*.private_ip
  description = "List of private ip's worker nodes"
}

output "worker_tags" {
  value = aws_spot_instance_request.talos_worker_instance.*.tags_all
  description = "All tags that are tagged for worker"
  
}
output "traefik_lb_endpoint" {
  value = aws_lb.traefik.dns_name
  description = "DNS Name for the CNAME creation"
  
}
