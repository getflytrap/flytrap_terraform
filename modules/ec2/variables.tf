variable "vpc_id" {
  description = "Flytrap VPC id"
  type        = string
}

variable "public_subnet_id" {
  description = "Flytrap public subnet id"
  type        = string
}

variable "lambda_sg_id" {
  description = "Lambda security group id for webhook connection"
  type        = string
}

variable "flytrap_db_sg_id" {
  description = "Flytrap RDS database security group id"
  type        = string
}

variable "db_arn" {
  description = "Flytrap RDS database ARN"
  type        = string
}

variable "db_host" {
  description = "Hostname for the Flytrap RDS database for psql"
  type        = string
}

variable "db_name" {
  description = "Flytrap RDS endpoint for db connection"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN for the db connection secret in Secret Manager"
  type        = string
}

variable "db_secret_name" {
  description = "AWS secret name for database credentials"
  type        = string
}

variable "aws_region" {
  description = "AWS region - setting as env variable for db connection in Flask"
  type        = string
}

variable "api_gateway_usage_plan_id" {
  description = "API Gateway useage plan ID for API keys "
  type        = string
}

variable "account_id" {
  description = "The AWS account ID"
  type        = string
}

variable "sdk_url" {
  description = "API Gateway base URL for SDKS"
  type        = string
}
