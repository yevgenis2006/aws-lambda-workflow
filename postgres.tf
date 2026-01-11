
# ----------------------
# POSTGRES RDS INSTANCE
# ----------------------
resource "aws_security_group" "rds_sg" {
  name        = "rds-sg"
  description = "Allow Lambda to access Postgres"
  vpc_id      = aws_vpc.main.id

  # Inbound: allow Lambda SG to connect to Postgres (port 5432)
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.lambda_sg.id]
  }

  # Allow specific IP
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["84.228.99.5/32"]  # replace with your IP
    description = "Allow my office IP"
  }

  # Outbound: allow all
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "rds-sg"
  }
}

# Subnet group for RDS (must be private subnets)
resource "aws_db_subnet_group" "rds_subnets" {
  name       = "rds-subnet-group"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = {
    Name = "rds-subnet-group"
  }
}

# RDS Postgres instance
resource "aws_db_instance" "postgres" {
  identifier             = "postgres-etl"
  allocated_storage      = 10
  engine                 = "postgres"
  engine_version         = "17.6"
  instance_class         = "db.t4g.micro"
  username               = "postgres"
  password               = "SuperSecret123!"
  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.rds_subnets.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  multi_az               = false
  publicly_accessible    = true
  skip_final_snapshot    = true
  deletion_protection    = false

  tags = {
    Name = "postgres-db"
  }
  depends_on = [aws_nat_gateway.nat]
}


# ----------------------
# Initialize DB + Tables
# ----------------------
resource "null_resource" "init_db" {
  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    command = <<EOT
timeout=300
elapsed=0
until PGPASSWORD="SuperSecret123!" psql -h ${aws_db_instance.postgres.endpoint} -p 5432 -U postgres -d postgres -c '\\q'; do
  sleep 10
  elapsed=$((elapsed + 10))
  if [ $elapsed -ge $timeout ]; then
    echo "RDS is still not available after 5 minutes, exiting..."
    exit 1
  fi
done
# Create database
PGPASSWORD="SuperSecret123!" psql -h ${aws_db_instance.postgres.endpoint} -p 5432 -U postgres -d postgres -c "CREATE DATABASE facebook;"

# Initialize tables
PGPASSWORD="SuperSecret123!" psql -v ON_ERROR_STOP=1 -h ${aws_db_instance.postgres.endpoint} -p 5432 -U postgres -d facebook -f ./init.sql
EOT
  }
}
