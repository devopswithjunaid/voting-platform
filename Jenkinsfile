pipeline {
  agent {
    kubernetes {
      yamlFile 'jenkins-working-template.yaml'
    }
  }
  
  environment {
    AWS_REGION = 'us-west-2'
    ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
    ECR_REPO_FRONTEND = 'voting-app-frontend'
    ECR_REPO_BACKEND = 'voting-app-backend'
    ECR_REPO_WORKER = 'voting-app-worker'
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
          '''
        }
      }
    }
    
    stage('Setup Tools') {
      steps {
        container('dind') {
          sh '''
            # Install AWS CLI
            apk add --no-cache aws-cli curl jq

            # Install kubectl
            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
            chmod +x kubectl
            mv kubectl /usr/local/bin/
          '''
        }
      }
    }
    
    stage('ECR Login') {
      steps {
        container('dind') {
          sh '''
            aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
          '''
        }
      }
    }
    
    stage('Build & Push Frontend') {
      steps {
        container('dind') {
          dir('frontend') {
            sh '''
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_FRONTEND:latest .
              docker tag $ECR_REPO_FRONTEND:latest $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest
              docker push $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest
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
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_BACKEND:latest .
              docker tag $ECR_REPO_BACKEND:latest $ECR_REGISTRY/$ECR_REPO_BACKEND:latest
              docker push $ECR_REGISTRY/$ECR_REPO_BACKEND:latest
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
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_WORKER:latest .
              docker tag $ECR_REPO_WORKER:latest $ECR_REGISTRY/$ECR_REPO_WORKER:latest
              docker push $ECR_REGISTRY/$ECR_REPO_WORKER:latest
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
              # Setup kubeconfig
              mkdir -p ~/.kube
              cat $KUBECONFIG > ~/.kube/config
              chmod 600 ~/.kube/config
              
              # Create namespace if it doesn't exist
              kubectl create namespace voting-app --dry-run=client -o yaml | kubectl apply -f -
              
              # Apply infrastructure first (Redis, PostgreSQL)
              echo "Deploying infrastructure..."
              kubectl apply -f k8s/redis.yaml -n voting-app
              kubectl apply -f k8s/postgres.yaml -n voting-app
              
              # Wait for infrastructure to be ready
              echo "Waiting for infrastructure..."
              kubectl wait --for=condition=available --timeout=300s deployment/redis -n voting-app || true
              kubectl wait --for=condition=available --timeout=300s deployment/db -n voting-app || true
              
              # Apply application deployments
              echo "Deploying applications..."
              kubectl apply -f k8s/frontend.yaml -n voting-app
              kubectl apply -f k8s/backend.yaml -n voting-app
              kubectl apply -f k8s/worker.yaml -n voting-app
              
              # Force restart all deployments to pull latest images
              echo "Forcing all deployments to pull latest images..."
              kubectl rollout restart deployment/frontend -n voting-app
              kubectl rollout restart deployment/backend -n voting-app
              kubectl rollout restart deployment/worker -n voting-app
              
              # Wait for all rollouts to complete
              echo "Waiting for frontend rollout to complete..."
              kubectl rollout status deployment/frontend -n voting-app --timeout=300s
              echo "Waiting for backend rollout to complete..."
              kubectl rollout status deployment/backend -n voting-app --timeout=300s
              echo "Waiting for worker rollout to complete..."
              kubectl rollout status deployment/worker -n voting-app --timeout=300s
              
              echo "All deployments restarted successfully!"
              
              # Wait for deployments (final check)
              echo "Final deployment status check..."
              kubectl rollout status deployment/frontend -n voting-app || true
              kubectl rollout status deployment/backend -n voting-app || true
              kubectl rollout status deployment/worker -n voting-app || true
            '''
          }
        }
      }
    }
    
    stage('Check Application Status') {
      steps {
        container('dind') {
          withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
            script {
              sh '''
                # Setup kubeconfig
                mkdir -p ~/.kube
                cat $KUBECONFIG > ~/.kube/config
                chmod 600 ~/.kube/config
                
                # Check deployment status
                echo "=== DEPLOYMENT STATUS ===" > app_status.txt
                
                # Frontend Status
                FRONTEND_STATUS=$(kubectl get deployment frontend -n voting-app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
                FRONTEND_READY=$(kubectl get deployment frontend -n voting-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                FRONTEND_DESIRED=$(kubectl get deployment frontend -n voting-app -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                
                echo "Frontend: $FRONTEND_STATUS ($FRONTEND_READY/$FRONTEND_DESIRED ready)" >> app_status.txt
                
                # Backend Status
                BACKEND_STATUS=$(kubectl get deployment backend -n voting-app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
                BACKEND_READY=$(kubectl get deployment backend -n voting-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                BACKEND_DESIRED=$(kubectl get deployment backend -n voting-app -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                
                echo "Backend: $BACKEND_STATUS ($BACKEND_READY/$BACKEND_DESIRED ready)" >> app_status.txt
                
                # Worker Status
                WORKER_STATUS=$(kubectl get deployment worker -n voting-app -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
                WORKER_READY=$(kubectl get deployment worker -n voting-app -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                WORKER_DESIRED=$(kubectl get deployment worker -n voting-app -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
                
                echo "Worker: $WORKER_STATUS ($WORKER_READY/$WORKER_DESIRED ready)" >> app_status.txt
                
                # Overall Status
                echo "" >> app_status.txt
                echo "=== PODS STATUS ===" >> app_status.txt
                kubectl get pods -n voting-app --no-headers | awk '{print $1 ": " $3 " (" $2 ")"}' >> app_status.txt
                
                # Service Status
                echo "" >> app_status.txt
                echo "=== SERVICES ===" >> app_status.txt
                kubectl get svc -n voting-app --no-headers | awk '{print $1 ": " $2 " (" $4 ")"}' >> app_status.txt
                
                # Overall health check
                if [ "$FRONTEND_STATUS" = "True" ] && [ "$BACKEND_STATUS" = "True" ] && [ "$WORKER_STATUS" = "True" ]; then
                  echo "" >> app_status.txt
                  echo "🟢 Overall Status: HEALTHY - All services running" >> app_status.txt
                else
                  echo "" >> app_status.txt
                  echo "🔴 Overall Status: UNHEALTHY - Some services down" >> app_status.txt
                fi
                
                # Display status
                cat app_status.txt
              '''
            }
          }
        }
      }
    }
  }
  
  post {
    always {
      container('dind') {
        sh '''
          docker rmi $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest || true
          docker rmi $ECR_REGISTRY/$ECR_REPO_BACKEND:latest || true
          docker rmi $ECR_REGISTRY/$ECR_REPO_WORKER:latest || true
          docker rmi $ECR_REPO_FRONTEND:latest || true
          docker rmi $ECR_REPO_BACKEND:latest || true
          docker rmi $ECR_REPO_WORKER:latest || true
        '''
      }
    }
    success {
      echo '''
        🎉 =================================="
        ✅ PIPELINE COMPLETED SUCCESSFULLY!"
        =================================="
        
        🎯 All custom images built and deployed!"
        🌐 Namespace: voting-app"
        
        📱 Access your application:"
        - kubectl get svc -n voting-app"
        
        🚀 Your voting app is now live!"
      '''
    }
    failure {
      echo '❌ Pipeline failed! Check logs for details.'
    }
  }
}
