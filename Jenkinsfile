pipeline {
  agent {
    kubernetes {
      yamlFile 'jenkins-dind-working-final.yaml'
    }
  }
  
  environment {
    AWS_REGION = 'us-west-2'
    ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
    ECR_REPO_FRONTEND = 'voting-app-frontend'
    ECR_REPO_BACKEND = 'voting-app-backend'
    ECR_REPO_WORKER = 'voting-app-worker'
    EKS_CLUSTER = 'infra-env-cluster'
    NAMESPACE = 'voting-app'
    KUBECONFIG_CREDENTIALS_ID = 'kubeconfig-credentials-id'
  }
  
  stages {
    stage('Checkout') {
      steps {
        checkout scm
      }
    }
    
    stage('Wait for Docker Daemon') {
      steps {
        container('dind') {
          sh '''
            echo "Waiting for Docker daemon to be ready..."
            until docker info > /dev/null 2>&1; do
              sleep 1
            done
            echo "Docker daemon is ready"
            docker --version
          '''
        }
      }
    }
    
    stage('Setup Tools') {
      steps {
        container('dind') {
          sh '''
            echo "Installing tools in DinD container..."
            
            # Install AWS CLI
            apk add --no-cache aws-cli curl jq

            # Install kubectl
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            mv kubectl /usr/local/bin/
            
            # Verify installations
            aws --version
            kubectl version --client
            echo "✅ All tools installed successfully!"
          '''
        }
      }
    }
    
    stage('AWS & EKS Setup') {
      steps {
        container('dind') {
          sh '''
            echo "Setting up AWS and EKS connection..."
            
            # Test AWS connection
            aws sts get-caller-identity
            
            # Update kubeconfig for EKS
            aws eks update-kubeconfig --region $AWS_REGION --name $EKS_CLUSTER
            kubectl get nodes
            
            echo "✅ AWS and EKS setup complete!"
          '''
        }
      }
    }
    
    stage('ECR Login') {
      steps {
        container('dind') {
          sh '''
            echo "Logging into ECR..."
            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
            echo "✅ ECR login successful!"
          '''
        }
      }
    }
    
    stage('Build & Push Frontend') {
      steps {
        container('dind') {
          dir('frontend') {
            sh '''
              echo "Building Frontend (Flask App)..."
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_FRONTEND:latest .
              docker tag $ECR_REPO_FRONTEND:latest $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest
              docker push $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest
              echo "✅ Frontend image pushed successfully!"
            '''
          }
        }
      }
    }
    
    stage('Build & Push Backend') {
      steps {
        container('dind') {
          dir('backend') {
            sh '''
              echo "Building Backend (Node.js App)..."
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_BACKEND:latest .
              docker tag $ECR_REPO_BACKEND:latest $ECR_REGISTRY/$ECR_REPO_BACKEND:latest
              docker push $ECR_REGISTRY/$ECR_REPO_BACKEND:latest
              echo "✅ Backend image pushed successfully!"
            '''
          }
        }
      }
    }
    
    stage('Build & Push Worker') {
      steps {
        container('dind') {
          dir('worker') {
            sh '''
              echo "Building Worker (.NET App)..."
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_WORKER:latest .
              docker tag $ECR_REPO_WORKER:latest $ECR_REGISTRY/$ECR_REPO_WORKER:latest
              docker push $ECR_REGISTRY/$ECR_REPO_WORKER:latest
              echo "✅ Worker image pushed successfully!"
            '''
          }
        }
      }
    }
    
    stage('Deploy to EKS') {
      steps {
        container('dind') {
          withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
            sh '''
              echo "Deploying to EKS with custom images..."
              
              # Setup kubeconfig
              mkdir -p ~/.kube
              cat $KUBECONFIG > ~/.kube/config
              chmod 600 ~/.kube/config
              
              # Create namespace
              kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
              
              # Deploy infrastructure first
              echo "Deploying infrastructure..."
              kubectl apply -f k8s/redis.yaml -n $NAMESPACE
              kubectl apply -f k8s/postgres.yaml -n $NAMESPACE
              
              # Wait for infrastructure
              echo "Waiting for infrastructure..."
              kubectl wait --for=condition=available --timeout=300s deployment/redis -n $NAMESPACE || true
              kubectl wait --for=condition=available --timeout=300s deployment/db -n $NAMESPACE || true
              
              # Deploy applications
              echo "Deploying applications..."
              kubectl apply -f k8s/frontend.yaml -n $NAMESPACE
              kubectl apply -f k8s/backend.yaml -n $NAMESPACE
              kubectl apply -f k8s/worker.yaml -n $NAMESPACE
              
              # Force restart to pull latest images
              echo "Restarting deployments with latest images..."
              kubectl rollout restart deployment/frontend -n $NAMESPACE
              kubectl rollout restart deployment/backend -n $NAMESPACE
              kubectl rollout restart deployment/worker -n $NAMESPACE
              
              # Wait for rollouts
              echo "Waiting for rollouts to complete..."
              kubectl rollout status deployment/frontend -n $NAMESPACE --timeout=300s
              kubectl rollout status deployment/backend -n $NAMESPACE --timeout=300s
              kubectl rollout status deployment/worker -n $NAMESPACE --timeout=300s
              
              echo "✅ All deployments completed successfully!"
              
              # Show final status
              echo "=== Final Deployment Status ==="
              kubectl get pods -n $NAMESPACE
              kubectl get svc -n $NAMESPACE
              
              echo ""
              echo "=== LoadBalancer URLs ==="
              echo "Frontend URL:"
              kubectl get svc frontend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Pending..."
              echo ""
              echo "Backend URL:"
              kubectl get svc backend -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Pending..."
            '''
          }
        }
      }
    }
  }
  
  post {
    always {
      container('dind') {
        sh '''
          echo "Cleaning up Docker images..."
          docker rmi $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest || true
          docker rmi $ECR_REGISTRY/$ECR_REPO_BACKEND:latest || true
          docker rmi $ECR_REGISTRY/$ECR_REPO_WORKER:latest || true
          docker rmi $ECR_REPO_FRONTEND:latest || true
          docker rmi $ECR_REPO_BACKEND:latest || true
          docker rmi $ECR_REPO_WORKER:latest || true
          docker system prune -f || true
        '''
      }
    }
    success {
      echo '''
        🎉 =================================="
        ✅ DOCKER-IN-DOCKER PIPELINE SUCCESS!"
        =================================="
        
        🎯 Custom Images Built & Deployed:"
        • Frontend: Flask voting app"
        • Backend: Node.js results app"
        • Worker: .NET vote processor"
        
        🚀 All images pushed to ECR and deployed to EKS!"
        
        📱 Access your application:"
        kubectl get svc -n voting-app"
        
        💡 Your custom code is now running in production!"
      '''
    }
    failure {
      echo '❌ Docker-in-Docker pipeline failed! Check logs for details.'
    }
  }
}
