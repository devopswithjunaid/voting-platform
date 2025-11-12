pipeline {
  agent any
  
  environment {
    AWS_REGION = 'us-west-2'
    ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
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
          echo "=== Direct Execution Approach ==="
          echo "AWS Region: ${AWS_REGION}"
          echo "ECR Registry: ${ECR_REGISTRY}"
          echo "EKS Cluster: ${EKS_CLUSTER}"
          echo "Commit ID: ${COMMIT_ID}"
          echo "Namespace: ${NAMESPACE}"
          
          # Check executor pod
          ${KUBECTL_PATH} get deployment jenkins-executor -n jenkins
          echo "✅ Executor pod ready!"
        '''
      }
    }
    
    stage('🔧 Setup Tools in Executor') {
      steps {
        sh '''
          echo "=== Installing Tools in Executor Pod ==="
          
          # Get executor pod name
          EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}')
          echo "Using executor pod: $EXECUTOR_POD"
          
          # Install tools
          ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
            apk add --no-cache aws-cli curl jq git
            
            # Install kubectl
            curl -LO 'https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl'
            chmod +x kubectl
            mv kubectl /usr/local/bin/
            
            echo 'Tools installed successfully!'
          "
        '''
      }
    }
    
    stage('📥 Copy Source Code') {
      steps {
        sh '''
          echo "=== Copying Source Code ==="
          
          EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}')
          
          # Copy source code to executor pod
          ${KUBECTL_PATH} cp . jenkins/$EXECUTOR_POD:/workspace/ -c tools
          
          ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
            cd /workspace
            ls -la
            echo 'Source code copied successfully!'
          "
        '''
      }
    }
    
    stage('🐳 Setup Docker & AWS') {
      steps {
        sh '''
          echo "=== Setting up Docker & AWS ==="
          
          EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}')
          
          ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
            # Wait for Docker daemon
            echo 'Waiting for Docker daemon...'
            for i in {1..60}; do
              if docker info >/dev/null 2>&1; then
                echo 'Docker daemon ready!'
                break
              fi
              sleep 2
            done
            
            # Setup AWS and EKS
            aws sts get-caller-identity
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
            kubectl get nodes
            
            echo 'Docker & AWS setup complete!'
          "
        '''
      }
    }
    
    stage('🔐 ECR Login & Build Images') {
      steps {
        sh '''
          echo "=== ECR Login & Building Images ==="
          
          EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}')
          
          ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
            cd /workspace
            
            # ECR Login
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
            
            # Build Frontend
            echo 'Building Frontend...'
            cd frontend
            docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
            docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
            docker push ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID}
            docker push ${ECR_REGISTRY}/voting-app-frontend:latest
            
            # Build Backend
            echo 'Building Backend...'
            cd ../backend
            docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
            docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
            docker push ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID}
            docker push ${ECR_REGISTRY}/voting-app-backend:latest
            
            # Build Worker
            echo 'Building Worker...'
            cd ../worker
            docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
            docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
            docker push ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID}
            docker push ${ECR_REGISTRY}/voting-app-worker:latest
            
            echo 'All images built and pushed successfully!'
          "
        '''
      }
    }
    
    stage('🚀 Deploy to EKS') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-credentials-id', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            echo "=== Deploying to EKS ==="
            
            EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}')
            
            # Copy kubeconfig to executor pod
            ${KUBECTL_PATH} cp $KUBECONFIG_FILE jenkins/$EXECUTOR_POD:/tmp/kubeconfig -c tools
            
            ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
              cd /workspace
              
              # Setup kubeconfig
              mkdir -p ~/.kube
              cp /tmp/kubeconfig ~/.kube/config
              chmod 600 ~/.kube/config
              
              # Create namespace
              kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
              
              # Deploy infrastructure
              echo 'Deploying infrastructure...'
              kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
              kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
              
              # Deploy applications
              echo 'Deploying applications...'
              kubectl apply -f k8s/frontend.yaml -n ${NAMESPACE}
              kubectl apply -f k8s/backend.yaml -n ${NAMESPACE}
              kubectl apply -f k8s/worker.yaml -n ${NAMESPACE}
              
              # Update to custom images
              kubectl set image deployment/frontend frontend=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} -n ${NAMESPACE}
              kubectl set image deployment/backend backend=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} -n ${NAMESPACE}
              kubectl set image deployment/worker worker=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} -n ${NAMESPACE}
              
              # Wait for rollout
              kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
              kubectl rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
              kubectl rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
              
              echo 'Deployment complete!'
              kubectl get pods -n ${NAMESPACE}
              kubectl get svc -n ${NAMESPACE}
            "
          '''
        }
      }
    }
    
    stage('✅ Verify Deployment') {
      steps {
        withCredentials([file(credentialsId: 'kubeconfig-credentials-id', variable: 'KUBECONFIG_FILE')]) {
          sh '''
            echo "=== Verifying Deployment ==="
            
            EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}')
            
            ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
              # Check deployment status
              kubectl get deployments -n ${NAMESPACE}
              kubectl get pods -n ${NAMESPACE}
              kubectl get svc -n ${NAMESPACE}
              
              echo 'Frontend URL:'
              kubectl get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo 'Pending...'
              echo ''
              echo 'Backend URL:'
              kubectl get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo 'Pending...'
            "
          '''
        }
      }
    }
  }
  
  post {
    success {
      sh '''
        echo ""
        echo "🎉 =================================="
        echo "✅ CUSTOM IMAGES DEPLOYED SUCCESS!"
        echo "=================================="
        echo ""
        echo "🎯 Custom Images Built & Deployed:"
        echo "• Frontend: Flask voting app (${COMMIT_ID})"
        echo "• Backend: Node.js results app (${COMMIT_ID})"
        echo "• Worker: .NET vote processor (${COMMIT_ID})"
        echo ""
        echo "📱 Access Commands:"
        echo "${KUBECTL_PATH} get svc -n voting-app"
        echo "${KUBECTL_PATH} get pods -n voting-app"
        echo ""
        echo "🚀 Your voting app is LIVE with custom images!"
      '''
    }
    failure {
      echo '❌ Pipeline failed! Check logs for details.'
    }
    always {
      sh '''
        # Cleanup
        EXECUTOR_POD=$(${KUBECTL_PATH} get pods -n jenkins -l app=jenkins-executor -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ ! -z "$EXECUTOR_POD" ]; then
          ${KUBECTL_PATH} exec $EXECUTOR_POD -n jenkins -c tools -- sh -c "
            docker system prune -af || true
            rm -rf /workspace/* || true
          " 2>/dev/null || echo "Cleanup completed"
        fi
        echo "🏁 Pipeline execution finished."
      '''
    }
  }
}
