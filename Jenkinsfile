pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: shell
    image: devopswithjunaid/jenkins-agent-with-tools:latest
    command: ["/bin/bash"]
    args: ["-c", "while true; do sleep 30; done"]
    tty: true
    env:
    - name: DOCKER_HOST
      value: tcp://dind:2375
    volumeMounts:
    - name: workspace
      mountPath: /workspace
  - name: dind
    image: docker:24.0-dind
    securityContext:
      privileged: true
    env:
    - name: DOCKER_TLS_CERTDIR
      value: ""
    args:
    - --insecure-registry=767225687948.dkr.ecr.us-west-2.amazonaws.com
    - --host=tcp://0.0.0.0:2375
    volumeMounts:
    - name: workspace
      mountPath: /workspace
    - name: docker-lib
      mountPath: /var/lib/docker
  volumes:
  - name: workspace
    emptyDir: {}
  - name: docker-lib
    emptyDir: {}
"""
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
        container('shell') {
          sh '''
            echo "=== Static Pod Environment ==="
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
            echo "✅ All tools ready!"
          '''
        }
      }
    }
    
    stage('🐳 Wait for Docker') {
      steps {
        container('shell') {
          sh '''
            echo "=== Waiting for Docker Daemon ==="
            for i in {1..60}; do
              if docker info >/dev/null 2>&1; then
                echo "✅ Docker daemon is ready!"
                break
              fi
              echo "Waiting for Docker daemon... ($i/60)"
              sleep 2
            done
            docker --version
          '''
        }
      }
    }
    
    stage('🔧 AWS & Kubernetes Setup') {
      steps {
        container('shell') {
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
        container('shell') {
          sh '''
            echo "=== ECR Login ==="
            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
            echo "✅ ECR login successful!"
          '''
        }
      }
    }
    
    stage('📦 Build Custom Images') {
      parallel {
        stage('🗳️ Frontend') {
          steps {
            container('shell') {
              sh '''
                echo "=== Building Frontend (Your Flask App) ==="
                cd frontend
                docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
                
                docker push ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-frontend:latest
                
                echo "✅ Frontend image pushed!"
              '''
            }
          }
        }
        
        stage('📊 Backend') {
          steps {
            container('shell') {
              sh '''
                echo "=== Building Backend (Your Node.js App) ==="
                cd backend
                docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
                
                docker push ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-backend:latest
                
                echo "✅ Backend image pushed!"
              '''
            }
          }
        }
        
        stage('⚙️ Worker') {
          steps {
            container('shell') {
              sh '''
                echo "=== Building Worker (Your .NET App) ==="
                cd worker
                docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
                docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
                
                docker push ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID}
                docker push ${ECR_REGISTRY}/voting-app-worker:latest
                
                echo "✅ Worker image pushed!"
              '''
            }
          }
        }
      }
    }
    
    stage('✅ Verify Images') {
      steps {
        container('shell') {
          sh '''
            echo "=== Verifying Custom Images ==="
            
            aws ecr describe-images --repository-name voting-app-frontend --image-ids imageTag=${COMMIT_ID} --region ${AWS_REGION} --query 'imageDetails[0].imageTags'
            aws ecr describe-images --repository-name voting-app-backend --image-ids imageTag=${COMMIT_ID} --region ${AWS_REGION} --query 'imageDetails[0].imageTags'
            aws ecr describe-images --repository-name voting-app-worker --image-ids imageTag=${COMMIT_ID} --region ${AWS_REGION} --query 'imageDetails[0].imageTags'
            
            echo "✅ All images verified!"
          '''
        }
      }
    }
    
    stage('🚀 Deploy to EKS') {
      steps {
        container('shell') {
          sh '''
            echo "=== Deploying to EKS ==="
            
            # Create namespace
            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            
            # Deploy infrastructure
            kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
            
            # Deploy applications
            kubectl apply -f k8s/frontend.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/backend.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/worker.yaml -n ${NAMESPACE}
            
            # Update images
            kubectl set image deployment/frontend frontend=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} -n ${NAMESPACE}
            kubectl set image deployment/backend backend=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} -n ${NAMESPACE}
            kubectl set image deployment/worker worker=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} -n ${NAMESPACE}
            
            # Wait for rollout
            kubectl rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
            kubectl rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
            kubectl rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
            
            echo "=== Deployment Complete ==="
            kubectl get pods -n ${NAMESPACE}
            kubectl get svc -n ${NAMESPACE}
            
            echo "Frontend URL:"
            kubectl get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Pending..."
            echo ""
            echo "Backend URL:"
            kubectl get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Pending..."
          '''
        }
      }
    }
  }
  
  post {
    success {
      echo '''
        🎉 =================================="
        ✅ CUSTOM IMAGES DEPLOYED SUCCESS!"
        =================================="
        
        🎯 Your Custom Apps Deployed:"
        • Frontend: Flask voting app"
        • Backend: Node.js results app"
        • Worker: .NET vote processor"
        
        📱 kubectl get svc -n voting-app"
        🚀 Your voting app is LIVE!"
      '''
    }
    failure {
      echo '❌ Pipeline failed! Check logs.'
    }
    always {
      container('shell') {
        sh 'docker system prune -af || true'
      }
    }
  }
}
