resource "aws_iam_role" "ec2_role" {
  name               = "flytrap-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Effect    = "Allow"
      }
    ]
  })
}

resource "aws_iam_policy" "ec2_permissions_policy" {
  name        = "EC2PermissionsPolicy"
  description = "Policy to allow EC2 instance to access RDS and CloudWatch"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "rds:DescribeDBInstances",
          "rds:Connect",
        ]
        Effect   = "Allow"
        Resource = var.db_arn
      },
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action   = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:CreateSecret"
        ],
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action    = [
          "ec2-instance-connect:SendSSHPublicKey"
        ],
        Effect    = "Allow"
        Resource  = "arn:aws:ec2:${var.aws_region}:${var.account_id}:instance/${aws_instance.flytrap_app.id}"
      },
      {
        Action  = [
          "apigateway:GET",
          "apigateway:POST",
          "apigateway:PUT",
          "apigateway:DELETE"
        ]
        Effect   = "Allow",
        Resource = "*"
      },
      {
        Action = [
          "sns:CreateTopic",
          "sns:Subscribe",
          "sns:Unsubscribe",
          "sns:DeleteTopic",
          "sns:Publish"
        ],
        Effect    = "Allow",
        Resource  = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ec2_rds_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.ec2_permissions_policy.arn
}

resource "aws_security_group" "flytrap_app_sg" {
  name        = "allow_http_https"
  description = "Allow EC2 permissions for HTTP, HTTPS, Lambda, RDS, RDS, SSH"
  vpc_id      = var.vpc_id

  tags = {
    Name = "Flytrap EC2 security group"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [var.lambda_sg_id]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [var.lambda_sg_id]
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.flytrap_db_sg_id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags = {
    Name = "public-route-table"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = var.vpc_id
}

resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = var.public_subnet_id
  route_table_id = aws_route_table.public.id
}

data "aws_secretsmanager_secret" "flytrap_db_secret" {
  name = var.db_secret_name
}

data "aws_secretsmanager_secret_version" "flytrap_db_secret_version" {
  secret_id = data.aws_secretsmanager_secret.flytrap_db_secret.id
}

locals {
  db_user     = jsondecode(data.aws_secretsmanager_secret_version.flytrap_db_secret_version.secret_string)["username"]
  db_password = jsondecode(data.aws_secretsmanager_secret_version.flytrap_db_secret_version.secret_string)["password"]
}

resource "random_password" "jwt_secret_key_value" {
  length           = 64
  special          = false
}

resource "aws_secretsmanager_secret" "jwt_secret_key" {
  name        = "jwt_secret_key"
  description = "JWT secret key for Flytrap API"
}

resource "aws_secretsmanager_secret_version" "jwt_secret_key_version" {
  secret_id     = aws_secretsmanager_secret.jwt_secret_key.id
  secret_string = jsonencode({
    jwt_secret_key = random_password.jwt_secret_key_value.result
  })
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "EC2InstanceProfileForRDSAccess"
  role = aws_iam_role.ec2_role.name
}

locals {
  setup_nginx_script = file("${path.module}/scripts/setup_nginx.sh")
}

resource "aws_instance" "flytrap_app" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t2.small"
  subnet_id                   = var.public_subnet_id
  security_groups             = [aws_security_group.flytrap_app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_instance_profile.name

  associate_public_ip_address = true
  metadata_options {
    http_tokens = "required"
    http_endpoint = "enabled"
  }

  user_data = templatefile("${path.module}/scripts/setup_scripts.sh", {
    setup_nginx_script        = local.setup_nginx_script
    db_host                   = var.db_host
    db_user                   = local.db_user
    db_name                   = var.db_name
    db_password               = local.db_password
    api_gateway_usage_plan_id = var.api_gateway_usage_plan_id
    aws_region                = var.aws_region
    sdk_url                   = var.sdk_url
  })

  tags = {
    Name = "FlytrapApp"
  }
}