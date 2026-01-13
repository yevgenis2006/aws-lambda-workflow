

provider "aws" {
  region = "us-west-2"
}

# --- DATA: availability zones ---
data "aws_availability_zones" "available" {}

# --- VPC ---
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "lambda-vpc"
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "lambda-igw"
  }
}

# --- Public Subnets ---
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
  }
}

# --- Private Subnets ---
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index}"
  }
}

# --- Elastic IP for NAT Gateway ---
resource "aws_eip" "nat" {
  #vpc = true
  depends_on = [aws_internet_gateway.igw]
}

# --- NAT Gateway ---
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name = "lambda-nat"
  }
}

# --- Route Table for Public Subnets ---
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-rt"
  }
}

# --- Associate Public Subnets ---
resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  #count         = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# --- Route Table for Private Subnets ---
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "private-rt"
  }
}

# --- Associate Private Subnets ---
resource "aws_route_table_association" "private_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- Security Group for Lambda ---
resource "aws_security_group" "lambda_sg" {
  name        = "lambda-sg"
  description = "Lambda security group"
  vpc_id      = aws_vpc.main.id

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Optional: inbound from RDS if needed
}

# --- IAM Role for Lambda ---
resource "aws_iam_role" "lambda_exec" {
  name = "lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# --- CloudWatch Log Group ---
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/facebook-json-to-postgres-etl"
  retention_in_days = 30
}

# --- Lambda Function ---
resource "aws_lambda_function" "etl" {
  function_name = "facebook-json-to-postgres-etl"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = "lambda-deployment.zip"
  source_code_hash = filebase64sha256("lambda-deployment.zip")

  timeout       = 600
  memory_size   = 1024
  architectures = ["arm64"]

  vpc_config {
    subnet_ids         = [for s in aws_subnet.private : s.id]
    security_group_ids = [aws_security_group.lambda_sg.id]
  }

  environment {
  variables = {
    DB_HOST = aws_db_instance.postgres.address
    DB_USER = "postgres"
    DB_PASS = "SuperSecret123!"
    DB_NAME = "facebook"
  }
}

  depends_on = [
  aws_db_instance.postgres
  ]
}

