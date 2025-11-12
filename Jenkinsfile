pipeline {
  agent {
    kubernetes {
      yamlFile 'jenkins-custom-agent.yaml'
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
            echo "=== Custom Jenkins Agent Environment ==="
            echo "AWS Region: ${AWS_REGION}"
            echo "ECR Registry: ${ECR_REGISTRY}"
            echo "EKS Cluster: ${EKS_CLUSTER}"
            echo "Commit ID: ${COMMIT_ID}"
            echo "Namespace: ${NAMESPACE}"
            echo ""
            
            echo "=== Tool Verification ==="
            aws --version
            kubectl version --client
            docker --version
            git --version
            echo "✅ All tools ready in custom image!"
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
    
    stage('🐳 Docker Service Setup') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== Docker Service Setup ==="
            # Start Docker daemon if needed
            sudo service docker start || echo "Docker already running"
            
            # Wait for Docker to be ready
            for i in {1..30}; do
              if docker info >/dev/null 2>&1; then
                echo "✅ Docker is ready!"
                break
              fi
              echo "Waiting for Docker... ($i/30)"
              sleep 2
            done
            
            docker --version
            docker info
          '''
        }
      }
    }
    
    stage('📦 Build Custom Images') {
      parallel {
        stage('🗳️ Frontend Service') {
          steps {
            container('jnlp') {
              sh '''
                echo "=== Building Frontend Image (Your Flask App) ==="
                
                # ECR Login
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                
                # Build image
                cd frontend
                docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
                
                # Push image
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
                
                # ECR Login
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                
                # Build image
                cd backend
                docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
                
                # Push image
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
                
                # ECR Login
                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                
                # Build image
                cd worker
                docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
                
                # Push image
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
            
            # Deploy infrastructure
            echo "Deploying infrastructure..."
            kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
            
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
  }
  
  post {
    success {
      echo """
      🎉 =================================="
      ✅ CUSTOM IMAGE PIPELINE SUCCESS!"
      =================================="
      
      🎯 Custom Images Built & Deployed:"
      • Frontend: Your Flask voting app (${COMMIT_ID})"
      • Backend: Your Node.js results app (${COMMIT_ID})"
      • Worker: Your .NET vote processor (${COMMIT_ID})"
      
      🚀 All images pushed to ECR and deployed to EKS!"
      🌐 Namespace: ${NAMESPACE}"
      
      📱 Access your CUSTOM voting app:"
      kubectl get svc -n voting-app"
      
      💡 Your code is now running in production!"
      """
    }
    failure {
      echo '❌ Custom image pipeline failed! Check logs.'
    }
    always {
      container('jnlp') {
        sh '''
          # Cleanup Docker images to save space
          docker system prune -af || true
          echo "🏁 Custom image pipeline finished."
        '''
      }
    }
  }
}
