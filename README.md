<img width="1536" height="1024" alt="image" src="https://github.com/user-attachments/assets/7f2ca4f1-76e8-41ea-b5fe-1ea7cb5a97ca" />


## AWS Architecture for Lambda ETL


🧱 Main components
```

✅ Public Subnets
✅ Internet Gateway (IGW)
✅ Lambda Function (ETL)
✅ Security Group
✅ PostgreSQL RDS

```

🚀 Deployment Options

terraform init
terraform validate
terraform plan -var-file="template.tfvars"
terraform apply -var-file="template.tfvars" -auto-approve
