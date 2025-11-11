pipeline {
  agent any
  
  environment {
    AWS_REGION = 'us-west-2'
    EKS_CLUSTER = 'infra-env-cluster'
    NAMESPACE = 'voting-app'
    COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    
    // Tool paths
    KUBECTL_PATH = '/var/jenkins_home/kubectl'
    AWS_PATH = '/var/jenkins_home/aws/dist/aws'
  }
  
  stages {
    stage('🔍 Environment Setup') {
      steps {
        sh '''
          echo "=== Environment Information ==="
          echo "AWS Region: ${AWS_REGION}"
          echo "EKS Cluster: ${EKS_CLUSTER}"
          echo "Commit ID: ${COMMIT_ID}"
          echo "Namespace: ${NAMESPACE}"
          echo ""
          
          echo "=== Tool Verification ==="
          ${AWS_PATH} --version
          ${KUBECTL_PATH} version --client
          git --version
          echo "✅ All tools verified!"
        '''
      }
    }
    
    stage('🔧 AWS & Kubernetes Setup') {
      steps {
        sh '''
          echo "=== AWS Configuration ==="
          ${AWS_PATH} sts get-caller-identity
          
          echo "=== Kubernetes Configuration ==="
          mkdir -p /var/jenkins_home/bin
          ln -sf ${AWS_PATH} /var/jenkins_home/bin/aws
          export PATH="/var/jenkins_home/bin:$PATH"
          
          ${AWS_PATH} eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
          ${KUBECTL_PATH} get nodes
          echo "✅ Cluster connection verified!"
        '''
      }
    }
    
    stage('📦 Prepare Deployment') {
      steps {
        sh '''
          echo "=== Preparing Deployment ==="
          echo "Using pre-built Docker images from Docker Hub"
          echo "Frontend: dockersamples/examplevotingapp_vote:latest"
          echo "Backend: dockersamples/examplevotingapp_result:latest"
          echo "Worker: dockersamples/examplevotingapp_worker:latest"
          echo "✅ Images ready for deployment!"
        '''
      }
    }
    
    stage('🚀 Deploy to EKS') {
      steps {
        sh '''
          echo "=== Deploying to EKS ==="
          
          # Setup PATH for aws command
          export PATH="/var/jenkins_home/bin:$PATH"
          
          # Create namespace if not exists
          ${KUBECTL_PATH} create namespace ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_PATH} apply -f -
          
          # Apply infrastructure first (Redis, PostgreSQL)
          echo "Deploying infrastructure..."
          ${KUBECTL_PATH} apply -f k8s/redis.yaml -n ${NAMESPACE}
          ${KUBECTL_PATH} apply -f k8s/postgres.yaml -n ${NAMESPACE}
          
          # Wait for infrastructure to be ready
          echo "Waiting for infrastructure..."
          ${KUBECTL_PATH} wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=120s || true
          ${KUBECTL_PATH} wait --for=condition=ready pod -l app=db -n ${NAMESPACE} --timeout=120s || true
          
          # Apply application deployments
          echo "Deploying applications..."
          ${KUBECTL_PATH} apply -f k8s/frontend.yaml -n ${NAMESPACE}
          ${KUBECTL_PATH} apply -f k8s/backend.yaml -n ${NAMESPACE}
          ${KUBECTL_PATH} apply -f k8s/worker.yaml -n ${NAMESPACE}
          
          # Force restart deployments to ensure latest deployment
          echo "Restarting deployments..."
          ${KUBECTL_PATH} rollout restart deployment/frontend -n ${NAMESPACE}
          ${KUBECTL_PATH} rollout restart deployment/backend -n ${NAMESPACE}
          ${KUBECTL_PATH} rollout restart deployment/worker -n ${NAMESPACE}
          
          # Wait for rollout
          echo "Waiting for deployments to complete..."
          ${KUBECTL_PATH} rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
          ${KUBECTL_PATH} rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
          ${KUBECTL_PATH} rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
          
          # Get service information
          echo "=== Deployment Status ==="
          ${KUBECTL_PATH} get pods -n ${NAMESPACE}
          ${KUBECTL_PATH} get svc -n ${NAMESPACE}
          
          echo ""
          echo "=== LoadBalancer URLs ==="
          echo "Frontend URL:"
          ${KUBECTL_PATH} get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
          echo ""
          echo "Backend URL:"
          ${KUBECTL_PATH} get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
        '''
      }
    }
    
    stage('✅ Verify Deployment') {
      steps {
        sh '''
          echo "=== Verifying Deployment ==="
          
          # Check pod status
          echo "Pod Status:"
          ${KUBECTL_PATH} get pods -n ${NAMESPACE} -o wide
          
          # Check service status
          echo ""
          echo "Service Status:"
          ${KUBECTL_PATH} get svc -n ${NAMESPACE}
          
          # Check deployment status
          echo ""
          echo "Deployment Status:"
          ${KUBECTL_PATH} get deployments -n ${NAMESPACE}
          
          echo ""
          echo "✅ Deployment verification complete!"
        '''
      }
    }
  }
  
  post {
    success {
      sh '''
        echo ""
        echo "🎉 =================================="
        echo "✅ PIPELINE COMPLETED SUCCESSFULLY!"
        echo "=================================="
        echo ""
        echo "🎯 Commit: ${COMMIT_ID}"
        echo "🌐 Namespace: ${NAMESPACE}"
        echo ""
        echo "📱 Access your application:"
        echo "- Frontend (Voting): ${KUBECTL_PATH} get svc frontend -n voting-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
        echo "- Backend (Results): ${KUBECTL_PATH} get svc backend -n voting-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
        echo ""
        echo "🔍 Check status: ${KUBECTL_PATH} get all -n voting-app"
        echo ""
        echo "🚀 Your voting app is now live!"
        echo ""
        echo "=== Quick Access Commands ==="
        echo "kubectl get svc -n voting-app"
        echo "kubectl get pods -n voting-app"
        echo "kubectl logs -f deployment/frontend -n voting-app"
      '''
    }
    failure {
      echo '❌ Pipeline failed! Check logs for details.'
    }
    always {
      echo '🏁 Pipeline execution finished.'
    }
  }
}
