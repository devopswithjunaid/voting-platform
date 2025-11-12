pipeline {
  agent any
  
  environment {
    AWS_REGION = 'us-west-2'
    ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
    EKS_CLUSTER = 'infra-env-cluster'
    NAMESPACE = 'voting-app'
    COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
    
    // Static pod name
    STATIC_POD = 'jenkins-static-agent'
    KUBECTL_PATH = '/var/jenkins_home/kubectl'
    AWS_PATH = '/var/jenkins_home/aws/dist/aws'
  }
  
  stages {
    stage('🔍 Environment Setup') {
      steps {
        sh '''
          echo "=== Using Static Pod Execution ==="
          echo "AWS Region: ${AWS_REGION}"
          echo "ECR Registry: ${ECR_REGISTRY}"
          echo "EKS Cluster: ${EKS_CLUSTER}"
          echo "Commit ID: ${COMMIT_ID}"
          echo "Namespace: ${NAMESPACE}"
          echo "Static Pod: ${STATIC_POD}"
          echo ""
          
          echo "=== Checking Static Pod ==="
          ${KUBECTL_PATH} get pod ${STATIC_POD} -n jenkins
          echo "✅ Static pod ready!"
        '''
      }
    }
    
    stage('🐳 Setup Docker in Static Pod') {
      steps {
        sh '''
          echo "=== Setting up Docker in Static Pod ==="
          
          # Wait for Docker daemon in static pod
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            echo 'Waiting for Docker daemon...'
            for i in {1..60}; do
              if docker info >/dev/null 2>&1; then
                echo '✅ Docker daemon ready!'
                break
              fi
              echo 'Waiting... (\$i/60)'
              sleep 2
            done
            docker --version
          "
        '''
      }
    }
    
    stage('🔧 AWS & Kubernetes Setup') {
      steps {
        sh '''
          echo "=== AWS & Kubernetes Setup in Static Pod ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            echo '=== AWS Configuration ==='
            aws sts get-caller-identity
            
            echo '=== Kubernetes Configuration ==='
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
            kubectl get nodes
            echo '✅ Cluster connection verified!'
          "
        '''
      }
    }
    
    stage('📥 Copy Source Code') {
      steps {
        sh '''
          echo "=== Copying Source Code to Static Pod ==="
          
          # Copy entire workspace to static pod
          ${KUBECTL_PATH} cp . jenkins/${STATIC_POD}:/workspace/ -c jenkins-agent
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            cd /workspace
            ls -la
            echo '✅ Source code copied!'
          "
        '''
      }
    }
    
    stage('🔐 ECR Login') {
      steps {
        sh '''
          echo "=== ECR Login in Static Pod ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
            echo '✅ ECR login successful!'
          "
        '''
      }
    }
    
    stage('📦 Build Frontend Image') {
      steps {
        sh '''
          echo "=== Building Frontend Image (Your Flask App) ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            cd /workspace/frontend
            docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
            docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
            
            docker push ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID}
            docker push ${ECR_REGISTRY}/voting-app-frontend:latest
            
            echo '✅ Frontend image (Flask app) pushed!'
          "
        '''
      }
    }
    
    stage('📦 Build Backend Image') {
      steps {
        sh '''
          echo "=== Building Backend Image (Your Node.js App) ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            cd /workspace/backend
            docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
            docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
            
            docker push ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID}
            docker push ${ECR_REGISTRY}/voting-app-backend:latest
            
            echo '✅ Backend image (Node.js app) pushed!'
          "
        '''
      }
    }
    
    stage('📦 Build Worker Image') {
      steps {
        sh '''
          echo "=== Building Worker Image (Your .NET App) ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            cd /workspace/worker
            docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
            docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
            
            docker push ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID}
            docker push ${ECR_REGISTRY}/voting-app-worker:latest
            
            echo '✅ Worker image (.NET app) pushed!'
          "
        '''
      }
    }
    
    stage('✅ Verify Images') {
      steps {
        sh '''
          echo "=== Verifying Custom Images in ECR ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            aws ecr describe-images --repository-name voting-app-frontend --image-ids imageTag=${COMMIT_ID} --region ${AWS_REGION} --query 'imageDetails[0].imageTags'
            aws ecr describe-images --repository-name voting-app-backend --image-ids imageTag=${COMMIT_ID} --region ${AWS_REGION} --query 'imageDetails[0].imageTags'
            aws ecr describe-images --repository-name voting-app-worker --image-ids imageTag=${COMMIT_ID} --region ${AWS_REGION} --query 'imageDetails[0].imageTags'
            
            echo '✅ All custom images verified!'
          "
        '''
      }
    }
    
    stage('🚀 Deploy to EKS') {
      steps {
        sh '''
          echo "=== Deploying Custom Images to EKS ==="
          
          ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
            cd /workspace
            
            # Create namespace
            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            
            # Deploy infrastructure
            kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
            
            # Deploy applications
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
            
            echo '=== Deployment Complete ==='
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
  
  post {
    success {
      sh '''
        echo ""
        echo "🎉 =================================="
        echo "✅ CUSTOM IMAGES DEPLOYED SUCCESS!"
        echo "=================================="
        echo ""
        echo "🎯 Your Custom Apps Deployed:"
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
        # Cleanup in static pod
        ${KUBECTL_PATH} exec ${STATIC_POD} -n jenkins -c jenkins-agent -- bash -c "
          docker system prune -af || true
          rm -rf /workspace/* || true
        " || echo "Cleanup completed"
        echo "🏁 Pipeline execution finished."
      '''
    }
  }
}
