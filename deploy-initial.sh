
#!/bin/bash

echo "🚀 Deploying Voting App to EKS Cluster..."

# Step 1: Connect to EKS cluster
echo "📡 Connecting to EKS cluster..."
aws eks update-kubeconfig --region us-west-2 --name secure-dev-env-cluster

# Step 2: Create k8s directory if not exists
mkdir -p k8s

# Step 3: Deploy in order (database first, then apps)
echo "🗄️  Deploying Database & Cache..."
kubectl apply -f k8s/database.yaml

echo "⏳ Waiting for database to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/db
kubectl wait --for=condition=available --timeout=300s deployment/redis

echo "🎨 Deploying Frontend..."
kubectl apply -f k8s/frontend.yaml

echo "⚙️  Deploying Backend..."
kubectl apply -f k8s/backend.yaml

echo "🔧 Deploying Worker..."
kubectl apply -f k8s/worker.yaml

# Step 4: Wait for all deployments
echo "⏳ Waiting for all deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/frontend
kubectl wait --for=condition=available --timeout=300s deployment/backend
kubectl wait --for=condition=available --timeout=300s deployment/worker

# Step 5: Show deployment status
echo "📊 Deployment Status:"
kubectl get deployments

echo "🌐 Services:"
kubectl get services

echo "🎯 Pods:"
kubectl get pods

echo "✅ Deployment completed successfully!"
echo "🔗 Access URLs will be available via LoadBalancer services"
