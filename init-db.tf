# ----------------------
# Initialize DB + Tables
# ----------------------
resource "null_resource" "init_db" {
  depends_on = [aws_db_instance.postgres]

  provisioner "local-exec" {
    command = <<EOT
set -e

timeout=300
elapsed=0

echo "Waiting for RDS..."

until PGPASSWORD="SuperSecret123!" psql -h ${aws_db_instance.postgres.endpoint} -p 5432 -U postgres -d postgres -c '\\q' > /dev/null 2>&1; do
  sleep 10
  elapsed=$((elapsed + 10))
  if [ $elapsed -ge $timeout ]; then
    echo "RDS is still not available after 5 minutes, exiting..."
    exit 1
  fi
done
echo "RDS is ready"

# Create database if not exists
PGPASSWORD="SuperSecret123!" psql -h ${aws_db_instance.postgres.endpoint} -p 5432 -U postgres -d postgres <<SQL
SELECT 'CREATE DATABASE facebook'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'facebook')\\gexec
SQL

# Initialize tables
PGPASSWORD="SuperSecret123!" psql -v ON_ERROR_STOP=1 \
  -h ${aws_db_instance.postgres.endpoint} \
  -p 5432 \
  -U postgres \
  -d facebook \
  -f .config/schema.sql

echo "Database initialized"
EOT
  }
}
