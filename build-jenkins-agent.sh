#!/bin/bash

# Build custom Jenkins agent image
docker build -f Dockerfile.jenkins-agent -t jenkins-agent-dind:latest .

# Tag for your registry (replace with your ECR/DockerHub)
docker tag jenkins-agent-dind:latest your-registry/jenkins-agent-dind:latest

# Push to registry
docker push your-registry/jenkins-agent-dind:latest

echo "✅ Jenkins agent image built and pushed successfully"
