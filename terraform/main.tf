##  VPC ##
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support = true
    tags = {
        Name = "${var.project_name}-vpc"
    }   
}

## Internet Gateway ##
resource "aws_internet_gateway" "igw"{
    vpc_id = aws_vpc.main.id
    tags = {
        Name = "${var.project_name}-igw"
    }
}

#####   SUBNETS ######
resource "aws_subnet" "public_a" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_a_cidr
  availability_zone = var.availability_zone_a
  map_public_ip_on_launch = true
  
    tags = {
        Name = "${var.project_name}-public-subnet-a"
    }
}
resource "aws_subnet" "public_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnet_b_cidr
    availability_zone = var.availability_zone_b
    map_public_ip_on_launch = true

    tags = {
      Name = "${var.project_name}-public-subnet-b"
    }
}

resource "aws_subnet" "private_a" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_a_cidr
    availability_zone = var.availability_zone_a
    map_public_ip_on_launch = false

    tags = {
      Name = "${var.project_name}-private-subnet-a"
    }
  
}
resource "aws_subnet" "private_b" {
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnet_b_cidr
    availability_zone = var.availability_zone_b
    map_public_ip_on_launch = false

    tags = {
      Name = "${var.project_name}-private-subnet-b"
    }
  
}

##### Elastic IP  #####
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

##### NAT Gateway #####
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id = aws_subnet.public_a.id
  tags = {
    Name = "${var.project_name}-nat-gateway"
  }
}

### ROUTe TABLES ###
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.igw.id
    }
    tags = {
        Name = "${var.project_name}-public-rt"
    }
}
resource "aws_route_table_association" "public_a_assoc" {
    subnet_id = aws_subnet.public_a.id
    route_table_id = aws_route_table.public_rt.id
  
}
resource "aws_route_table_association" "public_b_assoc"{
    subnet_id = aws_subnet.public_b.id
    route_table_id = aws_route_table.public_rt.id   
}

resource "aws_route_table" "private_rt"{
    vpc_id = aws_vpc.main.id
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat.id
  
}

    tags = {
        Name = "${var.project_name}-private-rt"
    }
}
resource "aws_route_table_association" "private_a_assoc" {
    subnet_id = aws_subnet.private_a.id
    route_table_id = aws_route_table.private_rt.id
}
resource "aws_route_table_association" "private_b_assoc" {
    subnet_id = aws_subnet.private_b.id
    route_table_id = aws_route_table.private_rt.id
}


######## security group ######

### for ALB ###
resource "aws_security_group" "alb_sg"{
    name = "${var.project_name}-ALB-sg"
    description = "Security group for application load balancer"
    vpc_id = aws_vpc.main.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        }
    egress {
        from_port = 0
        to_port= 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.project_name}-ALB-sg"
    }

}

### for EC2 instances ###
resource "aws_security_group" "ec2_sg" {
    name ="${var.project_name}-EC2-sg"
    description = "security group for EC2 instances"
    vpc_id = aws_vpc.main.id
    ingress{
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "${var.project_name}-EC2-sg"
    }
}

### RDS security group ###
resource "aws_security_group" "rds_sg" {
    name = "${var.project_name}-RDS-sg"
    description = "security group for RDS instances"
    vpc_id = aws_vpc.main.id
    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        security_groups = [aws_security_group.ec2_sg.id]

    }
    egress {
        from_port =0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
      Name= "${var.project_name}-RDS-sg"
    }
  
}


#### Application load balancer ####

resource "aws_lb" "alb" {
        name = "${var.project_name}-ALB"
        load_balancer_type = "application"
        internal = false
        security_groups = [aws_security_group.alb_sg.id]
        subnets = [aws_subnet.public_a.id, aws_subnet.public_b.id]
        tags = {
            Name = "${var.project_name}-ALB"
}
  
}
resource "aws_lb_target_group" "tg" {
    name ="${var.project_name}-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main.id
    health_check {
        path="/"
        protocol = "HTTP"
        interval = 30
        timeout = 5
        healthy_threshold = 5
        unhealthy_threshold = 2

    }
}

resource "aws_lb_listener" "listener" {
    load_balancer_arn = aws_lb.alb.arn
    port = 80
    protocol = "HTTP"
    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.tg.arn
    }
  
}


#### launch template for EC2 instances ####
resource "aws_launch_template" "app" {
    name = "${var.project_name}-launch-template"
    # key_name = 
    image_id = "ami-0c83cb1c664994bbd" # Amazon Linux 2 AMI (HVM), SSD Volume Type in eu-north-1
    instance_type = "t3.micro"
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
    # security_group_names = [aws_security_group.ec2_sg.id]
    user_data = base64encode(<<-EOF
                #!/bin/bash
                yum update -y
                yum install -y httpd
                systemctl start httpd
                systemctl enable httpd
                echo "<h1>Hello from the Private Subnet via ASG!</h1>" > /var/www/html/index.html
                EOF
    )

    lifecycle {
      create_before_destroy = true
    }
}

######## Auto Scaling Group ######
resource "aws_autoscaling_group" "ec2_asg"{
    name = "${var.project_name}-asg"
    desired_capacity = 2
    max_size = 4
    min_size = 1
    # For private subnets, we need to specify the subnet IDs directly
    vpc_zone_identifier = [ aws_subnet.private_a.id, aws_subnet.private_b.id ]
    # Link the ASG to the ALB Target Group
    target_group_arns = [ aws_lb_target_group.tg.arn ]
    launch_template {
      id = aws_launch_template.app.id
      version ="$Latest"
    }
    # Use ELB health checks instead of just EC2 checks
    health_check_type = "ELB"
    health_check_grace_period = 300
    tag {
      key = "Name"
      value = "ASG-app-server"
      propagate_at_launch = true
    }
}

##### RDS subnet group #####
resource "aws_db_subnet_group" "rds_subnet_group" {
    name = "${var.project_name}-rds-subnet-group"
    subnet_ids = [aws_subnet.private_a.id,aws_subnet.private_b.id]
    tags = {
        Name = "${var.project_name}-rds-subnet-group"
    }
}

###### RDS instance ######
resource "aws_db_instance" "rds" {
    allocated_storage = 20
    # storage_type = "gp2"
    engine = "mysql"
    engine_version = "8.0"
    instance_class = "db.t3.micro"
    db_name = "mydb"
    username = "admin"
    password = "password123"
    db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids = [aws_security_group.rds_sg.id]

    multi_az = true
    skip_final_snapshot = true
    publicly_accessible = false


}
