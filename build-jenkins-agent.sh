#!/bin/bash

# Build and push Jenkins agent image
echo "Building Jenkins agent image..."
docker build -t devopswithjunaid/jenkins-agent-with-tools:latest -f Dockerfile.jenkins-agent .

echo "Pushing to Docker Hub..."
docker login --username devopswithjunaid
docker push devopswithjunaid/jenkins-agent-with-tools:latest

echo "Jenkins agent image ready!"
