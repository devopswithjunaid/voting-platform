#!/bin/bash

echo "🔧 Setting up Kubernetes Plugin for Jenkins..."

# Connect via VPN server to restart Jenkins
VPN_SERVER="35.85.108.1"
KEY_PATH="~/.ssh/secure-dev-keypair"

echo "Connecting to VPN server to restart Jenkins..."

ssh -i $KEY_PATH ubuntu@$VPN_SERVER << 'EOF'
echo "🔄 Restarting Jenkins to load Kubernetes plugin..."

# Restart Jenkins deployment
kubectl rollout restart deployment/jenkins -n jenkins

echo "⏳ Waiting for Jenkins to restart..."
kubectl rollout status deployment/jenkins -n jenkins --timeout=300s

echo "✅ Jenkins restarted!"
echo "🌐 Access Jenkins at: http://35.85.108.1:8080"

# Check if Jenkins is responding
sleep 30
curl -I http://10.0.3.235:31667 || echo "Jenkins still starting..."

echo "📋 Next steps:"
echo "1. Go to Manage Jenkins → Manage Plugins"
echo "2. Install Kubernetes plugin if not already installed"
echo "3. Go to Manage Jenkins → Configure System"
echo "4. Look for 'Cloud' section at the bottom"
echo "5. Add Kubernetes cloud configuration"
EOF

echo "✅ Jenkins restart completed!"
echo "🔗 Access Jenkins: http://35.85.108.1:8080"
