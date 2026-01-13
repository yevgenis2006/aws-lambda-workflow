# ----------------------
# Initialize DB + Tables
# ----------------------
resource "null_resource" "init_db" {
  # Ensure DB is created only after RDS is available
  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for RDS to be ready..."
      until PGPASSWORD="${var.db_password}" psql -h ${aws_db_instance.postgres.address} -U postgres -d postgres -c "\\q" 2>/dev/null; do
        sleep 5
      done

      echo "Creating database 'facebook'..."
      PGPASSWORD="${var.db_password}" psql -h ${aws_db_instance.postgres.address} -U postgres -d postgres -c "CREATE DATABASE facebook;"

      echo "Initialize tables..."
      PGPASSWORD="${var.db_password}" psql -h ${aws_db_instance.postgres.address} -U postgres -d facebook -f config/schema.sql
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

variable "db_password" {
  description = "Postgres password"
  type        = string
  default     = "SuperSecret123!"
}

