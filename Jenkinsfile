pipeline {
  agent {
    kubernetes {
      yamlFile 'jenkins-dind-custom.yaml'
    }
  }
  
  environment {
    AWS_REGION = 'us-west-2'
    ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
    EKS_CLUSTER = 'infra-env-cluster'
    NAMESPACE = 'voting-app'
    COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
  }
  
  stages {
    stage('🔍 Environment Setup') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== Custom Jenkins Agent with DinD ==="
            echo "AWS Region: ${AWS_REGION}"
            echo "ECR Registry: ${ECR_REGISTRY}"
            echo "EKS Cluster: ${EKS_CLUSTER}"
            echo "Commit ID: ${COMMIT_ID}"
            echo "Namespace: ${NAMESPACE}"
            echo ""
            
            echo "=== Tool Verification ==="
            aws --version
            kubectl version --client
            git --version
            echo "✅ All tools ready in custom image!"
          '''
        }
      }
    }
    
    stage('🐳 Wait for Docker Daemon') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== Waiting for Docker Daemon ==="
            until docker info > /dev/null 2>&1; do
              echo "Waiting for Docker daemon..."
              sleep 2
            done
            echo "✅ Docker daemon is ready!"
            docker --version
          '''
        }
      }
    }
    
    stage('🔧 AWS & Kubernetes Setup') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== AWS Configuration ==="
            aws sts get-caller-identity
            
            echo "=== Kubernetes Configuration ==="
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
            kubectl get nodes
            echo "✅ Cluster connection verified!"
          '''
        }
      }
    }
    
    stage('🔐 ECR Login') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== ECR Login ==="
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
            echo "✅ ECR login successful!"
          '''
        }
      }
    }
    
    stage('📦 Build & Push Custom Images') {
      parallel {
        stage('🗳️ Frontend Service') {
          steps {
            container('jnlp') {
              sh '''
                echo "=== Building Frontend Image (Your Flask App) ==="
                cd frontend
                docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
                
                docker push ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-frontend:latest
                
                echo "✅ Frontend image (your Flask app) pushed successfully!"
              '''
            }
          }
        }
        
        stage('📊 Backend Service') {
          steps {
            container('jnlp') {
              sh '''
                echo "=== Building Backend Image (Your Node.js App) ==="
                cd backend
                docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
                
                docker push ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-backend:latest
                
                echo "✅ Backend image (your Node.js app) pushed successfully!"
              '''
            }
          }
        }
        
        stage('⚙️ Worker Service') {
          steps {
            container('jnlp') {
              sh '''
                echo "=== Building Worker Image (Your .NET App) ==="
                cd worker
                docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
                
                docker push ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-worker:latest
                
                echo "✅ Worker image (your .NET app) pushed successfully!"
              '''
            }
          }
        }
      }
    }
    
    stage('✅ Verify Custom Images') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== Verifying Custom Images in ECR ==="
            
            echo "Frontend images:"
            aws ecr describe-images \\
              --repository-name voting-app-frontend \\
              --image-ids imageTag=${COMMIT_ID} \\
              --region ${AWS_REGION} \\
              --query 'imageDetails[0].imageTags'
            
            echo "Backend images:"
            aws ecr describe-images \\
              --repository-name voting-app-backend \\
              --image-ids imageTag=${COMMIT_ID} \\
              --region ${AWS_REGION} \\
              --query 'imageDetails[0].imageTags'
            
            echo "Worker images:"
            aws ecr describe-images \\
              --repository-name voting-app-worker \\
              --image-ids imageTag=${COMMIT_ID} \\
              --region ${AWS_REGION} \\
              --query 'imageDetails[0].imageTags'
            
            echo "✅ All custom images verified in ECR!"
          '''
        }
      }
    }
    
    stage('🚀 Deploy to EKS') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== Deploying Custom Images to EKS ==="
            
            # Create namespace
            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            
            # Deploy infrastructure first
            echo "Deploying infrastructure..."
            kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
            
            # Wait for infrastructure
            echo "Waiting for infrastructure..."
            kubectl wait --for=condition=available --timeout=300s deployment/redis -n ${NAMESPACE} || true
            kubectl wait --for=condition=available --timeout=300s deployment/db -n ${NAMESPACE} || true
            
            # Deploy applications
            echo "Deploying applications with custom images..."
            kubectl apply -f k8s/frontend.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/backend.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/worker.yaml -n ${NAMESPACE}
            
            # Update to use new custom images
            echo "Updating to custom images with commit: ${COMMIT_ID}"
            kubectl set image deployment/frontend \\
              frontend=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} \\
              -n ${NAMESPACE}
            
            kubectl set image deployment/backend \\
              backend=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} \\
              -n ${NAMESPACE}
            
            kubectl set image deployment/worker \\
              worker=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} \\
              -n ${NAMESPACE}
            
            # Wait for rollout
            echo "Waiting for custom image deployments..."
            kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
            kubectl rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
            kubectl rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
            
            echo "=== Custom Image Deployment Complete ==="
            kubectl get pods -n ${NAMESPACE}
            kubectl get svc -n ${NAMESPACE}
            
            echo ""
            echo "=== Your Custom Voting App URLs ==="
            echo "Frontend URL:"
            kubectl get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
            echo ""
            echo "Backend URL:"
            kubectl get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
          '''
        }
      }
    }
    
    stage('📊 Application Status') {
      steps {
        container('jnlp') {
          script {
            sh '''
              # Check deployment status
              echo "=== DEPLOYMENT STATUS ===" > app_status.txt
              
              # Frontend Status
              FRONTEND_STATUS=$(kubectl get deployment frontend -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
              FRONTEND_READY=$(kubectl get deployment frontend -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
              FRONTEND_DESIRED=$(kubectl get deployment frontend -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
              
              echo "Frontend: $FRONTEND_STATUS ($FRONTEND_READY/$FRONTEND_DESIRED ready)" >> app_status.txt
              
              # Backend Status
              BACKEND_STATUS=$(kubectl get deployment backend -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
              BACKEND_READY=$(kubectl get deployment backend -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
              BACKEND_DESIRED=$(kubectl get deployment backend -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
              
              echo "Backend: $BACKEND_STATUS ($BACKEND_READY/$BACKEND_DESIRED ready)" >> app_status.txt
              
              # Worker Status
              WORKER_STATUS=$(kubectl get deployment worker -n ${NAMESPACE} -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
              WORKER_READY=$(kubectl get deployment worker -n ${NAMESPACE} -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
              WORKER_DESIRED=$(kubectl get deployment worker -n ${NAMESPACE} -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
              
              echo "Worker: $WORKER_STATUS ($WORKER_READY/$WORKER_DESIRED ready)" >> app_status.txt
              
              # Overall Status
              echo "" >> app_status.txt
              echo "=== PODS STATUS ===" >> app_status.txt
              kubectl get pods -n ${NAMESPACE} --no-headers | awk '{print $1 ": " $3 " (" $2 ")"}' >> app_status.txt
              
              # Service Status
              echo "" >> app_status.txt
              echo "=== SERVICES ===" >> app_status.txt
              kubectl get svc -n ${NAMESPACE} --no-headers | awk '{print $1 ": " $2 " (" $4 ")"}' >> app_status.txt
              
              # Overall health check
              if [ "$FRONTEND_STATUS" = "True" ] && [ "$BACKEND_STATUS" = "True" ] && [ "$WORKER_STATUS" = "True" ]; then
                echo "" >> app_status.txt
                echo "🟢 Overall Status: HEALTHY - All services running" >> app_status.txt
              else
                echo "" >> app_status.txt
                echo "🟡 Overall Status: DEPLOYING - Some services starting" >> app_status.txt
              fi
              
              # Display status
              cat app_status.txt
            '''
          }
        }
      }
    }
  }
  
  post {
    always {
      container('jnlp') {
        sh '''
          # Cleanup Docker images to save space
          docker system prune -af || true
        '''
      }
    }
    success {
      echo '''
        🎉 =================================="
        ✅ CUSTOM IMAGE PIPELINE SUCCESS!"
        =================================="
        
        🎯 Custom Images Built & Deployed:"
        • Frontend: Your Flask voting app"
        • Backend: Your Node.js results app"
        • Worker: Your .NET vote processor"
        
        🚀 All images pushed to ECR and deployed to EKS!"
        
        📱 Access your CUSTOM voting app:"
        kubectl get svc -n voting-app"
        
        💡 Your code is now running in production!"
      '''
    }
    failure {
      echo '❌ Custom image pipeline failed! Check logs.'
    }
  }
}
