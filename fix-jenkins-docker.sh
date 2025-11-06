#!/bin/bash

echo "🔧 Fixing Jenkins Docker Access..."

# Stop current Jenkins container
echo "Stopping Jenkins container..."
docker stop jenkins || true

# Remove old container
echo "Removing old Jenkins container..."
docker rm jenkins || true

# Start Jenkins with Docker socket mounted
echo "Starting Jenkins with Docker access..."
docker run -d \
  --name jenkins \
  -p 31667:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /usr/bin/docker:/usr/bin/docker:ro \
  --group-add $(getent group docker | cut -d: -f3) \
  jenkins/jenkins:lts

echo "✅ Jenkins restarted with Docker access!"
echo "🔗 Access Jenkins at: http://localhost:31667"
echo "⏳ Wait 2-3 minutes for Jenkins to start, then run your pipeline"
