# Deploy GVM installation on AWS

This code shows how to deploy this GVM installation using
Terraform in AWS for educational purposes.

Please keep in mind to destroy the resources afterwards
as it costs money.

## How-To

Startup:
```bash
./prepare.sh
terraform init
terraform apply
```

Deletion:
```bash
terraform destroy
```
