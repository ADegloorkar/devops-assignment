# -------------------------
# VPC
# -------------------------

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# -------------------------
# Default Security Group
# -------------------------

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name = "${var.project_name}-default-sg"
  }
}

# -------------------------
# Public Subnet
# -------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# -------------------------
# Internet Gateway
# -------------------------

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# -------------------------
# Route Table
# -------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# -------------------------
# Application Security Group
# -------------------------

resource "aws_security_group" "app_sg" {
  #checkov:skip=CKV_AWS_260:Public HTTP is intentional for the sample web application.

  name        = "${var.project_name}-app-sg"
  description = "Security group for the application"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Public HTTP access for sample application"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow HTTPS outbound"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS UDP outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow DNS TCP outbound"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

# -------------------------
# IAM Role for Application EC2
# -------------------------

resource "aws_iam_role" "app_server_role" {
  name = "${var.project_name}-app-server-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.app_server_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_server" {
  name = "${var.project_name}-app-server-profile"
  role = aws_iam_role.app_server_role.name
}

# -------------------------
# EC2 Application Server
# -------------------------

resource "aws_instance" "app_server" {
  #checkov:skip=CKV_AWS_88:Public IP is required for direct HTTP access to this non-production demo app.

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  associate_public_ip_address = true

  iam_instance_profile = aws_iam_instance_profile.app_server.name

  monitoring    = true
  ebs_optimized = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name        = "${var.project_name}-app-server"
    Environment = "NonProd"
    Autostop    = "true"
  }
}

# -------------------------
# VPC Flow Logs
# -------------------------
# KMS encryption key for CloudWatch logs

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

resource "aws_kms_key" "vpc_logs" {
  description             = "KMS key for VPC Flow Logs encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "EnableAccountRootPermissions"
        Effect = "Allow"

        Principal = {
          AWS = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"
        }

        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowCloudWatchLogsEncryption"
        Effect = "Allow"

        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }

        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]

        Resource = "*"

        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/vpc/${var.project_name}-flow-logs"
          }
        }
      }
    ]
  })
  tags = {
    Name = "${var.project_name}-logs-key"
  }
}


# CloudWatch log group

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.project_name}-flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.vpc_logs.arn
}

resource "aws_iam_role" "flow_logs_role" {
  name = "${var.project_name}-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "${var.project_name}-flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

resource "aws_flow_log" "main" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs_role.arn

  depends_on = [
    aws_iam_role_policy.flow_logs_policy
  ]
}

# -------------------------
# Latest Ubuntu AMI
# -------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# IAM Role for EC2 Scheduler Lambda
resource "aws_iam_role" "ec2_scheduler_lambda_role" {
  name = "${var.project_name}-ec2-scheduler-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}
# Allow Lambda to write logs to CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.ec2_scheduler_lambda_role.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Allow Lambda to manage only eligible non-production EC2 instances

resource "aws_iam_role_policy" "ec2_scheduler_permissions" {
  name = "${var.project_name}-ec2-scheduler-permissions"
  role = aws_iam_role.ec2_scheduler_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:StartInstances",
          "ec2:StopInstances"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:ec2:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Environment" = "NonProd"
            "ec2:ResourceTag/Autostop"    = "true"
          }
        }
      }
    ]
  })
}

# Package Python Lambda function

data "archive_file" "ec2_scheduler" {
  type        = "zip"
  source_file = "${path.module}/../scripts/ec2_scheduler.py"
  output_path = "${path.module}/ec2_scheduler.zip"
}


# Lambda function to start EC2 instances
resource "aws_lambda_function" "ec2_start_scheduler" {
  #checkov:skip=CKV_AWS_297:Customer-managed KMS encryption is not required for this assignment.
  function_name = "${var.project_name}-ec2-start"
  role          = aws_iam_role.ec2_scheduler_lambda_role.arn

  runtime = "python3.12"
  handler = "ec2_scheduler.lambda_handler"

  filename         = data.archive_file.ec2_scheduler.output_path
  source_code_hash = data.archive_file.ec2_scheduler.output_base64sha256

  timeout = 60

  environment {
    variables = {
      ACTION = "start"
    }
  }
  #checkov:skip=CKV_AWS_173:ACTION is a non-sensitive environment variable.
  #checkov:skip=CKV_AWS_116:Dead letter queue is not required for this assignment.
  #checkov:skip=CKV_AWS_117:Lambda calls EC2 APIs and does not require VPC attachment.
  #checkov:skip=CKV_AWS_272:Code signing is outside this assignment scope.

  reserved_concurrent_executions = 1

  tracing_config {
    mode = "Active"
  }
}

# Lambda function to stop EC2 instances
resource "aws_lambda_function" "ec2_stop_scheduler" {
  #checkov:skip=CKV_AWS_297:Customer-managed KMS encryption is not required for this assignment.
  function_name = "${var.project_name}-ec2-stop"
  role          = aws_iam_role.ec2_scheduler_lambda_role.arn

  runtime = "python3.12"
  handler = "ec2_scheduler.lambda_handler"

  filename         = data.archive_file.ec2_scheduler.output_path
  source_code_hash = data.archive_file.ec2_scheduler.output_base64sha256

  timeout = 60

  environment {
    variables = {
      ACTION = "stop"
    }
  }

  #checkov:skip=CKV_AWS_173:ACTION is a non-sensitive environment variable.
  #checkov:skip=CKV_AWS_116:Dead letter queue is not required for this assignment.
  #checkov:skip=CKV_AWS_117:Lambda calls EC2 APIs and does not require VPC attachment.
  #checkov:skip=CKV_AWS_272:Code signing is outside this assignment scope.

  reserved_concurrent_executions = 1

  tracing_config {
    mode = "Active"
  }
}


# IAM Role for EventBridge Scheduler
resource "aws_iam_role" "scheduler_invoke_lambda_role" {
  name = "${var.project_name}-scheduler-invoke-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "scheduler.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Allow EventBridge Scheduler to invoke both Lambda functions
resource "aws_iam_role_policy" "scheduler_invoke_lambda_policy" {
  name = "${var.project_name}-scheduler-invoke-lambda-policy"
  role = aws_iam_role.scheduler_invoke_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "lambda:InvokeFunction"
      ]
      Resource = [
        aws_lambda_function.ec2_start_scheduler.arn,
        aws_lambda_function.ec2_stop_scheduler.arn
      ]
    }]
  })
}

# Schedule to start non-production EC2 instances at 9 AM IST
resource "aws_scheduler_schedule" "ec2_start_schedule" {
  #checkov:skip=CKV_AWS_297:Customer-managed KMS encryption is not required for this assignment.
  name                         = "${var.project_name}-ec2-start-schedule"
  schedule_expression          = "cron(0 9 * * ? *)"
  schedule_expression_timezone = "Asia/Kolkata"
  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.ec2_start_scheduler.arn
    role_arn = aws_iam_role.scheduler_invoke_lambda_role.arn
  }
}

# Schedule to stop non-production EC2 instances at 9 PM IST
resource "aws_scheduler_schedule" "ec2_stop_schedule" {
  #checkov:skip=CKV_AWS_297:Customer-managed KMS encryption is not required for this assignment.
  name                         = "${var.project_name}-ec2-stop-schedule"
  schedule_expression          = "cron(0 21 * * ? *)"
  schedule_expression_timezone = "Asia/Kolkata"

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = aws_lambda_function.ec2_stop_scheduler.arn
    role_arn = aws_iam_role.scheduler_invoke_lambda_role.arn
  }
}
