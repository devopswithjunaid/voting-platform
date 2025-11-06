#!/bin/bash

echo "🏗️ Creating ECR Repository..."

# Set AWS credentials (use environment variables)
export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=us-west-2

# Create ECR repository
aws ecr create-repository --repository-name voting-app --region us-west-2

echo "✅ ECR Repository created successfully!"
echo "📝 Repository URI: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app"
