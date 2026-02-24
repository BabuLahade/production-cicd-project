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
  count = 2
  tags = {
    Name = "${var.project_name}-nat-eip"
  }
}

##### NAT Gateway #####
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat[count.index].id
  subnet_id = [aws_subnet.public_a.id, aws_subnet.public_b.id][count.index]
  depends_on = [ aws_internet_gateway.igw ]
  count = 2
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
    count = 2
    route {
        cidr_block = "0.0.0.0/0"
        nat_gateway_id = aws_nat_gateway.nat[count.index].id
  
}

    tags = {
        Name = "${var.project_name}-private-rt-${count.index}"
    }
}

resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = [aws_subnet.private_a.id, aws_subnet.private_b.id][count.index]
  route_table_id = aws_route_table.private_rt[count.index].id
}
# resource "aws_route_table_association" "private_a_assoc" {
#     subnet_id = aws_subnet.private_a.id
#     route_table_id = aws_route_table.private_rt.id
# }
# resource "aws_route_table_association" "private_b_assoc" {
#     subnet_id = aws_subnet.private_b.id
#     route_table_id = aws_route_table.private_rt.id
# }


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

##### AMI image 
# data "aws_ami" "amazon_linux" {
#     most_recent = true
#     filter {
#         name = "name"
#         values = ["amzn2-ami-hvm-*-x86_64-gp2"]
#     }
#     filter {
#         name = "virtualization-type"
#         values = ["hvm"]
#     }
#     owners = ["137112412989"] # Amazon
# }
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}
#### launch template for EC2 instances ####
resource "aws_launch_template" "app" {
    name = "${var.project_name}-launch-template"
    key_name = var.key_pair_name 
    # image_id = "ami-0c83cb1c664994bbd" # Amazon Linux 2 AMI (HVM), SSD Volume Type in eu-north-1
    instance_type = var.instance_type
    image_id = data.aws_ami.amazon_linux.id
    iam_instance_profile {
        name = aws_iam_instance_profile.ec2_profile.name
    }
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
    password = var.db_password
    db_subnet_group_name = aws_db_subnet_group.rds_subnet_group.name
    vpc_security_group_ids = [aws_security_group.rds_sg.id]

    multi_az = true
    skip_final_snapshot = true
    publicly_accessible = false


}

####### S3,Lambda, Event ######
resource "aws_s3_bucket" "my_bucket" {
    bucket = "${var.project_name}-bucket-uploads"
   
    tags = {
        Name = "${var.project_name}-bucket-uploads"
    }
}
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.my_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_lambda_function" "my_lambda" {
    filename = "lambda_function.zip"
    function_name = "s3-event-processor"
    role = aws_iam_role.lambda_exec_role.arn
    handler = "index.handler"
    runtime = "python3.9"
}

### permissions for Lambda to access S3 ###
resource "aws_lambda_permission" "allow_s3" {
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.my_lambda.function_name
    principal = "s3.amazonaws.com"
    source_arn = aws_s3_bucket.my_bucket.arn
}

#### EVENT NOTIFICATION for S3 to trigger Lambda ####
resource "aws_s3_bucket_notification" "trigger" {
    bucket = aws_s3_bucket.my_bucket.id
    lambda_function {
      lambda_function_arn = aws_lambda_function.my_lambda.arn
      events = ["s3:objectCreated:*"]  ## trigger when we upload somethings
    }
}

######### IAM Roles ANd Policies ##########
resource "aws_iam_role" "ec2_role" {
    name = "${var.project_name}-ec2-role"
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ec2_attach" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
# resource "aws_iam_role_policy_attachment" "s3_read_only" {
#     role = aws_iam_role.ec2_role.name
#     policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
# }

resource "aws_iam_policy" "ec2_s3_policy" {
  name = "${var.project_name}-ec2-s3-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.my_bucket.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${aws_s3_bucket.my_bucket.arn}/*"
      }
    ]
  })
}
resource "aws_iam_role_policy_attachment" "ec2_s3_attach" {
    role = aws_iam_role.ec2_role.name
    policy_arn = aws_iam_policy.ec2_s3_policy.arn
}
resource "aws_iam_role_policy_attachment" "CloudWatch_logs" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/cloudWatchAgentsServerPolicy"
}


resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}
####### CloudWatch Logs,Metrics,Alarms ######
resource "aws_cloudwatch_log_group" "app_logs" {
    name = "/aws/ec2/${var.project_name}-app-logs"
    retention_in_days = 7
}
## create sns for alarm notifications
resource "aws_sns_topic" "alarm_topic" {
    name = "${var.project_name}-alarm-topic"

}
#### subscription for sns topic ####
resource "aws_sns_topic_subscription" "alarm_subscription" {
  topic_arn = aws_sns_topic.alarm_topic.arn
  protocol = "email"
  endpoint = var.alarm_email
}


#### create an alarm for high CPU utilization on EC2 instances ####
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
    alarm_name = "${var.project_name}-high-cpu-alarm"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "180"
    statistic = "Average"
    threshold = "80"
    alarm_description = "this metric monitors ec2 cpu utilization"

    # trigger the sns topic 
    alarm_actions = [aws_sns_topic.alarm_topic.arn]

    # dimensions = {
    #     aws_autoscaling_groupName = aws_autoscaling_group.ec2_asg.name
    # }
    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.ec2_asg.name
        
}
}

# resource "aws_cloudwatch_dashboard" "main" {
#   dashboard_name = "${var.project_name}-Monitoring"

#   dashboard_body = jsonencode({
#     widgets = [
#       {
#         type   = "metric"
#         x      = 0
#         y      = 0
#         width  = 12
#         height = 6
#         properties = {
#           metrics = [
#             ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", "${aws_autoscaling_group.ec2_asg.name}"]
#           ]
#           period = 300
#           stat   = "Average"
#           region = "eu-north-1"
#           title  = "Average CPU Usage"
#         }
#       },
#       {
#         type   = "metric"
#         x      = 12
#         y      = 0
#         width  = 12
#         height = 6
#         properties = {
#           metrics = [
#             ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${aws_lb.alb.arn_suffix}"]
#           ]
#           period = 300
#           stat   = "Sum"
#           region = "eu-north-1"
#           title  = "Total ALB Requests"
#         }
#       }
#     ]
#   })
# }


########### WAF 
resource "aws_wafv2_web_acl" "alb_waf" {
  name  = "${var.project_name}-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }
}
resource "aws_wafv2_web_acl_association" "alb_assoc" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.alb_waf.arn
}
##########VPC FLow logs
# resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
#   name              = "/aws/vpc/${var.project_name}-flow-logs"
#   retention_in_days = 7
# }
# resource "aws_iam_role" "vpc_flow_logs_role" {
#   name = "${var.project_name}-vpc-flow-logs-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Principal = {
#         Service = "vpc-flow-logs.amazonaws.com"
#       }
#       Action = "sts:AssumeRole"
#     }]
#   })
# }
# resource "aws_iam_role_policy" "vpc_flow_logs_policy" {
#   name = "${var.project_name}-vpc-flow-logs-policy"
#   role = aws_iam_role.vpc_flow_logs_role.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Effect = "Allow"
#       Action = [
#         "logs:CreateLogStream",
#         "logs:PutLogEvents",
#         "logs:DescribeLogGroups",
#         "logs:DescribeLogStreams"
#       ]
#       Resource = "*"
#     }]
#   })
# }
# resource "aws_flow_log" "vpc_flow_logs" {
#   vpc_id               = aws_vpc.main.id
#   traffic_type         = "ALL"
#   log_destination_type = "cloud-watch-logs"
#   log_group_name       = aws_cloudwatch_log_group.vpc_flow_logs.name
#   iam_role_arn         = aws_iam_role.vpc_flow_logs_role.arn
# }
# 1. Create the IAM Role for Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# 2. Attach basic execution permissions (logging)
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}