# AWS Deployment Guide

Deploy PromptForge on AWS using ECS, RDS, and other managed services.

## Architecture

- **Compute**: ECS Fargate
- **Database**: RDS PostgreSQL
- **Load Balancer**: Application Load Balancer
- **Storage**: S3 (for static assets)
- **CDN**: CloudFront
- **DNS**: Route 53
- **Secrets**: AWS Secrets Manager

## Prerequisites

- AWS CLI configured
- Terraform (optional)
- Domain name

## Quick Deploy (ECS)

1. **Create RDS Database**
```bash
aws rds create-db-instance \
  --db-instance-identifier promptforge-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username promptforge \
  --master-user-password YourSecurePassword \
  --allocated-storage 20
```

2. **Create ECS Cluster**
```bash
aws ecs create-cluster --cluster-name promptforge-cluster
```

3. **Push Docker Images to ECR**
```bash
# Create ECR repositories
aws ecr create-repository --repository-name promptforge-backend
aws ecr create-repository --repository-name promptforge-frontend

# Build and push
$(aws ecr get-login --no-include-email --region us-east-1)
docker build -t promptforge-backend ./backend
docker tag promptforge-backend:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/promptforge-backend:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/promptforge-backend:latest
```

4. **Create ECS Task Definition**
```json
{
  "family": "promptforge-backend",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "backend",
      "image": "<account-id>.dkr.ecr.us-east-1.amazonaws.com/promptforge-backend:latest",
      "portMappings": [
        {
          "containerPort": 8000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "ENVIRONMENT", "value": "production"}
      ],
      "secrets": [
        {
          "name": "DATABASE_URL",
          "valueFrom": "arn:aws:secretsmanager:region:account-id:secret:promptforge/database-url"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/promptforge-backend",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
```

5. **Create ECS Service**
```bash
aws ecs create-service \
  --cluster promptforge-cluster \
  --service-name promptforge-backend-service \
  --task-definition promptforge-backend \
  --desired-count 2 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

## Using AWS Secrets Manager

```bash
# Store secrets
aws secretsmanager create-secret \
  --name promptforge/database-url \
  --secret-string "postgresql://user:pass@rds-endpoint:5432/promptforge"

aws secretsmanager create-secret \
  --name promptforge/secret-key \
  --secret-string "your-secret-key"

aws secretsmanager create-secret \
  --name promptforge/gemini-api-key \
  --secret-string "your-gemini-key"
```

## CloudFront + S3 for Frontend

```bash
# Create S3 bucket
aws s3 mb s3://promptforge-frontend-bucket

# Build and upload frontend
cd frontend
npm run build
aws s3 sync dist/ s3://promptforge-frontend-bucket

# Create CloudFront distribution
aws cloudfront create-distribution \
  --origin-domain-name promptforge-frontend-bucket.s3.amazonaws.com \
  --default-root-object index.html
```

## Monitoring with CloudWatch

```bash
# Create log groups
aws logs create-log-group --log-group-name /ecs/promptforge-backend

# Create alarms
aws cloudwatch put-metric-alarm \
  --alarm-name promptforge-high-cpu \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 2 \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --period 300 \
  --statistic Average \
  --threshold 70
```
