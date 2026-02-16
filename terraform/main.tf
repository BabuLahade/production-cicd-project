##  VPC ##
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr.id
  
    tags = {
        Name = "${var.project_name}-vpc"
    }   
}