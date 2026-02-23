variable "vpc_cidr" {
  description = "The CIDR block for the VPC."
  type        = string
  
}
variable "project_name" {
    description = "project name"
    type = string
  
}

variable "public_subnet_a_cidr" {
  description = "the cidr block ip range for public subnet a"
  type = string
}
variable "availability_zone_a" {
  description = "availability zone for a"
  type = string
}
variable "public_subnet_b_cidr" {
  description = "public subnet_b cidr ranges"
  type = string
}
variable "availability_zone_b" {
  description = "availability zone for b"
  type = string
}
variable "private_subnet_a_cidr" {
  description = "the cidr block ip range for private subnet a"
  type = string
}
variable "private_subnet_b_cidr" {
  description = "the cidr block ip range for private subnet b"
  type = string
  
}
variable "db_password" {
  description = "RDS root password"
  type        = string
  sensitive   = true
}
variable "key_pair_name" {
  description = "key pair name "
  type = string
}

variable "alarm_email" {
  description = "email address for alarm notifications"
  type = string
}

variable "instance_type" {
  description = "instance type for our EC2 instance"
  type = string
}