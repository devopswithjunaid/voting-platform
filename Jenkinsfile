pipeline {
  agent {
    kubernetes {
      yamlFile 'jenkins-simple-pod.yaml'
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
        container('aws-cli') {
          sh '''
            echo "=== Environment Information ==="
            echo "AWS Region: ${AWS_REGION}"
            echo "ECR Registry: ${ECR_REGISTRY}"
            echo "EKS Cluster: ${EKS_CLUSTER}"
            echo "Commit ID: ${COMMIT_ID}"
            echo "Namespace: ${NAMESPACE}"
            echo ""
            
            echo "=== Tool Verification ==="
            aws --version
            echo "✅ AWS CLI ready!"
          '''
        }
        container('kubectl') {
          sh '''
            kubectl version --client
            echo "✅ kubectl ready!"
          '''
        }
        container('kaniko') {
          sh '''
            echo "Kaniko executor ready!"
            ls -la /kaniko/.docker/ || echo "ECR credentials will be mounted"
            echo "✅ Kaniko ready!"
          '''
        }
      }
    }
    
    stage('🔧 AWS & Kubernetes Setup') {
      steps {
        container('aws-cli') {
          sh '''
            echo "=== AWS Configuration ==="
            aws sts get-caller-identity
            
            echo "=== Kubernetes Configuration ==="
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
          '''
        }
        container('kubectl') {
          sh '''
            kubectl get nodes
            echo "✅ Cluster connection verified!"
          '''
        }
      }
    }
    
    stage('📦 Build & Push Images with Kaniko') {
      parallel {
        stage('🗳️ Frontend Service') {
          steps {
            container('kaniko') {
              sh """
                echo "=== Building Frontend Image with Kaniko ==="
                /kaniko/executor \\
                  --context=\${WORKSPACE}/frontend \\
                  --dockerfile=\${WORKSPACE}/frontend/Dockerfile \\
                  --destination=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} \\
                  --destination=${ECR_REGISTRY}/voting-app-frontend:latest \\
                  --cache=true \\
                  --cache-ttl=24h
                echo "✅ Frontend image built and pushed!"
              """
            }
          }
        }
        
        stage('📊 Backend Service') {
          steps {
            container('kaniko') {
              sh """
                echo "=== Building Backend Image with Kaniko ==="
                /kaniko/executor \\
                  --context=\${WORKSPACE}/backend \\
                  --dockerfile=\${WORKSPACE}/backend/Dockerfile \\
                  --destination=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} \\
                  --destination=${ECR_REGISTRY}/voting-app-backend:latest \\
                  --cache=true \\
                  --cache-ttl=24h
                echo "✅ Backend image built and pushed!"
              """
            }
          }
        }
        
        stage('⚙️ Worker Service') {
          steps {
            container('kaniko') {
              sh """
                echo "=== Building Worker Image with Kaniko ==="
                /kaniko/executor \\
                  --context=\${WORKSPACE}/worker \\
                  --dockerfile=\${WORKSPACE}/worker/Dockerfile \\
                  --destination=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} \\
                  --destination=${ECR_REGISTRY}/voting-app-worker:latest \\
                  --cache=true \\
                  --cache-ttl=24h
                echo "✅ Worker image built and pushed!"
              """
            }
          }
        }
      }
    }
    
    stage('✅ Verify Images') {
      steps {
        container('aws-cli') {
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
        container('kubectl') {
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
      echo """
      🎉 =================================="
      ✅ PIPELINE COMPLETED SUCCESSFULLY!"
      =================================="
      
      🎯 Commit: ${COMMIT_ID}"
      🌐 Namespace: ${NAMESPACE}"
      
      📱 Access your application:"
      - Frontend (Voting): kubectl get svc frontend -n voting-app"
      - Backend (Results): kubectl get svc backend -n voting-app"
      
      🔍 Check status: kubectl get all -n voting-app"
      
      🚀 Your voting app is now live!"
      """
    }
    failure {
      echo '❌ Pipeline failed! Check logs for details.'
    }
    always {
      echo '🏁 Pipeline execution finished.'
    }
  }
}
