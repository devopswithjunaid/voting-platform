#!/bin/bash

echo "🏗️ Building Jenkins Agent with Docker, AWS CLI, kubectl..."

# Login to DockerHub (use your Docker token)
echo "$DOCKER_TOKEN" | docker login -u devopswithjunaid --password-stdin

# Build the image
docker build -f Dockerfile.jenkins-agent -t jenkins-agent-dind:latest .

# Tag for DockerHub
docker tag jenkins-agent-dind:latest devopswithjunaid/jenkins-agent-dind:latest

# Push to DockerHub
docker push devopswithjunaid/jenkins-agent-dind:latest

echo "✅ Image built and pushed successfully!"
