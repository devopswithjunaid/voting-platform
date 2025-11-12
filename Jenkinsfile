pipeline {
  agent {
    kubernetes {
      yamlFile '02-jenkins-dind-pod-template.yaml'
    }
  }

  environment {
    AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
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
            echo "Waiting for Docker daemon..."
            until docker info > /dev/null 2>&1; do sleep 1; done
            echo "Docker daemon ready"
          '''
        }
      }
    }

    stage('Verify Tools') {
      steps {
        container('jnlp') {
          sh '''
            echo "=== Tool Versions ==="
            kubectl version --client --short || echo "kubectl not found"
            aws --version || echo "aws cli not found"
            docker --version || echo "docker not found"
            helm version --short || echo "helm not found"
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
          '''
        }
      }
    }

    stage('Build & Push Frontend') {
      steps {
        container('dind') {
          dir('frontend') {
            sh '''
              echo "Building Frontend..."
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_FRONTEND:latest .
              docker tag $ECR_REPO_FRONTEND:latest $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest
              docker push $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest
              echo "Frontend pushed successfully"
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
              echo "Building Backend..."
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_BACKEND:latest .
              docker tag $ECR_REPO_BACKEND:latest $ECR_REGISTRY/$ECR_REPO_BACKEND:latest
              docker push $ECR_REGISTRY/$ECR_REPO_BACKEND:latest
              echo "Backend pushed successfully"
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
              echo "Building Worker..."
              DOCKER_BUILDKIT=1 docker build -t $ECR_REPO_WORKER:latest .
              docker tag $ECR_REPO_WORKER:latest $ECR_REGISTRY/$ECR_REPO_WORKER:latest
              docker push $ECR_REGISTRY/$ECR_REPO_WORKER:latest
              echo "Worker pushed successfully"
            '''
          }
        }
      }
    }

    stage('Deploy to EKS') {
      steps {
        container('jnlp') {
          withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
            sh '''
              echo "Setting up kubectl..."
              mkdir -p ~/.kube
              cat $KUBECONFIG > ~/.kube/config
              chmod 600 ~/.kube/config

              echo "Deploying to Kubernetes..."
              kubectl apply -f k8s/postgres.yaml
              kubectl apply -f k8s/redis.yaml
              kubectl apply -f k8s/backend.yaml
              kubectl apply -f k8s/frontend.yaml
              kubectl apply -f k8s/worker.yaml

              echo "Restarting deployments to pick latest images..."
              kubectl rollout restart deployment frontend backend worker db redis || true
              kubectl rollout status deployment frontend --timeout=300s || true
              kubectl rollout status deployment backend --timeout=300s || true
              kubectl rollout status deployment worker --timeout=300s || true
            '''
          }
        }
      }
    }

    stage('Check Application Status') {
      steps {
        container('jnlp') {
          withCredentials([file(credentialsId: env.KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
            sh '''
              mkdir -p ~/.kube
              cat $KUBECONFIG > ~/.kube/config
              chmod 600 ~/.kube/config
              
              echo "=== DEPLOYMENTS ==="
              kubectl get deploy
              echo "=== PODS ==="
              kubectl get pods
              echo "=== SERVICES ==="
              kubectl get svc
            '''
          }
        }
      }
    }
  }

  post {
    always {
      script {
        try {
          container('dind') {
            sh '''
              echo "Cleaning up Docker images..."
              docker rmi $ECR_REGISTRY/$ECR_REPO_FRONTEND:latest || true
              docker rmi $ECR_REGISTRY/$ECR_REPO_BACKEND:latest || true
              docker rmi $ECR_REGISTRY/$ECR_REPO_WORKER:latest || true
            '''
          }
        } catch (Exception e) {
          echo "Cleanup failed: ${e.getMessage()}"
        }
      }
    }
    success { 
      echo 'Pipeline completed successfully!' 
    }
    failure { 
      echo 'Pipeline failed. Check logs for details.' 
    }
  }
}
