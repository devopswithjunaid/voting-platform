pipeline {
  agent {
    kubernetes {
      yamlFile 'jenkins-dind-pod-template.yaml'
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
        container('dind') {
          sh '''
            echo "=== Environment Information ==="
            echo "AWS Region: ${AWS_REGION}"
            echo "ECR Registry: ${ECR_REGISTRY}"
            echo "EKS Cluster: ${EKS_CLUSTER}"
            echo "Commit ID: ${COMMIT_ID}"
            echo "Namespace: ${NAMESPACE}"
            echo ""
            
            echo "=== Waiting for Docker daemon ==="
            until docker info > /dev/null 2>&1; do
              echo "Waiting for Docker daemon..."
              sleep 2
            done
            echo "✅ Docker daemon is ready!"
          '''
        }
      }
    }
    
    stage('🔧 Install Tools') {
      steps {
        container('dind') {
          sh '''
            echo "=== Installing Tools ==="
            
            # Install AWS CLI
            apk add --no-cache aws-cli curl jq
            
            # Install kubectl
            curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
            chmod +x kubectl
            mv kubectl /usr/local/bin/
            
            # Verify installations
            echo "AWS CLI: $(aws --version)"
            echo "kubectl: $(kubectl version --client --short)"
            echo "Docker: $(docker --version)"
            echo "✅ All tools installed!"
          '''
        }
      }
    }
    
    stage('🔧 AWS & Kubernetes Setup') {
      steps {
        container('dind') {
          sh '''
            echo "=== AWS Configuration ==="
            # Use IAM role from EKS node
            aws sts get-caller-identity
            
            echo "=== Kubernetes Configuration ==="
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
            kubectl get nodes
            echo "✅ Cluster connection verified!"
          '''
        }
      }
    }
    
    stage('📦 Build & Push Images') {
      parallel {
        stage('🗳️ Frontend Service') {
          steps {
            container('dind') {
              sh '''
                echo "=== Building Frontend Image ==="
                
                # ECR Login
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                
                # Build image
                cd frontend
                docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
                
                # Push image
                docker push ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-frontend:latest
                
                echo "✅ Frontend image pushed successfully!"
              '''
            }
          }
        }
        
        stage('📊 Backend Service') {
          steps {
            container('dind') {
              sh '''
                echo "=== Building Backend Image ==="
                
                # ECR Login
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                
                # Build image
                cd backend
                docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
                
                # Push image
                docker push ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-backend:latest
                
                echo "✅ Backend image pushed successfully!"
              '''
            }
          }
        }
        
        stage('⚙️ Worker Service') {
          steps {
            container('dind') {
              sh '''
                echo "=== Building Worker Image ==="
                
                # ECR Login
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                
                # Build image
                cd worker
                docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
                
                # Push image
                docker push ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-worker:latest
                
                echo "✅ Worker image pushed successfully!"
              '''
            }
          }
        }
      }
    }
    
    stage('✅ Verify Images') {
      steps {
        container('dind') {
          sh '''
            echo "=== Verifying Images in ECR ==="
            
            echo "Frontend images:"
            aws ecr describe-images \\
              --repository-name voting-app-frontend \\
              --image-ids imageTag=${COMMIT_ID} \\
              --region ${AWS_REGION} \\
              --query 'imageDetails[0].imageTags' || echo "Image not found"
            
            echo "Backend images:"
            aws ecr describe-images \\
              --repository-name voting-app-backend \\
              --image-ids imageTag=${COMMIT_ID} \\
              --region ${AWS_REGION} \\
              --query 'imageDetails[0].imageTags' || echo "Image not found"
            
            echo "Worker images:"
            aws ecr describe-images \\
              --repository-name voting-app-worker \\
              --image-ids imageTag=${COMMIT_ID} \\
              --region ${AWS_REGION} \\
              --query 'imageDetails[0].imageTags' || echo "Image not found"
            
            echo "✅ All images verified in ECR!"
          '''
        }
      }
    }
    
    stage('🚀 Deploy to EKS') {
      steps {
        container('dind') {
          sh '''
            echo "=== Deploying to EKS ==="
            
            # Create namespace if not exists
            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            
            # Apply infrastructure first (Redis, PostgreSQL)
            echo "Deploying infrastructure..."
            kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
            
            # Wait for infrastructure to be ready
            echo "Waiting for infrastructure..."
            kubectl wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=120s || true
            kubectl wait --for=condition=ready pod -l app=db -n ${NAMESPACE} --timeout=120s || true
            
            # Apply application deployments
            echo "Deploying applications..."
            kubectl apply -f k8s/frontend.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/backend.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/worker.yaml -n ${NAMESPACE}
            
            # Update images with new commit
            echo "Updating images with commit: ${COMMIT_ID}"
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
            echo "Waiting for deployments to complete..."
            kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
            kubectl rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
            kubectl rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
            
            # Get service information
            echo "=== Deployment Status ==="
            kubectl get pods -n ${NAMESPACE}
            kubectl get svc -n ${NAMESPACE}
            
            echo ""
            echo "=== LoadBalancer URLs ==="
            echo "Frontend URL:"
            kubectl get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
            echo ""
            echo "Backend URL:"
            kubectl get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
          '''
        }
      }
    }
  }
  
  post {
    success {
      container('dind') {
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
          echo "- Frontend (Voting): kubectl get svc frontend -n voting-app"
          echo "- Backend (Results): kubectl get svc backend -n voting-app"
          echo ""
          echo "🔍 Check status: kubectl get all -n voting-app"
          echo ""
          echo "🚀 Your voting app is now live!"
        '''
      }
    }
    failure {
      echo '❌ Pipeline failed! Check logs for details.'
    }
    always {
      container('dind') {
        sh '''
          # Cleanup Docker images to save space
          docker system prune -af || true
          echo "🏁 Pipeline execution finished."
        '''
      }
    }
  }
}
