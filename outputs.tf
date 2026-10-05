output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "public_subnets" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnets" {
  description = "IDs of the private subnets."
  value       = module.vpc.private_subnets
}

output "database_subnet_group" {
  description = "Name of the database subnet group."
  value       = module.vpc.database_subnet_group
}

output "web_security_group_id" {
  description = "ID of the web security group."
  value       = module.web_sg.id
}
