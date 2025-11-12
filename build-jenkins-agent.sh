#!/bin/bash

# Build custom Jenkins agent image
echo "=== Building Custom Jenkins Agent Image ==="

# Build the image
docker build -f Dockerfile.jenkins-agent -t devopswithjunaid/jenkins-agent-with-tools:latest .

# Tag for Docker Hub
docker tag devopswithjunaid/jenkins-agent-with-tools:latest devopswithjunaid/jenkins-agent-with-tools:v1.0

echo "=== Testing Image ==="
# Test the image
docker run --rm devopswithjunaid/jenkins-agent-with-tools:latest /bin/bash -c "
echo 'Testing tools...'
aws --version
kubectl version --client
docker --version
echo 'All tools working!'
"

echo "=== Push to Docker Hub ==="
echo "Run these commands to push:"
echo "docker login"
echo "docker push devopswithjunaid/jenkins-agent-with-tools:latest"
echo "docker push devopswithjunaid/jenkins-agent-with-tools:v1.0"

echo "✅ Custom Jenkins agent image ready!"
