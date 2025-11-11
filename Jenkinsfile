pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins
  containers:
  - name: jnlp
    image: jenkins/inbound-agent:latest
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/cat"]
    tty: true
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  - name: kubectl
    image: bitnami/kubectl:latest
    command: ["cat"]
    tty: true
  - name: aws-cli
    image: amazon/aws-cli:latest
    command: ["cat"]  
    tty: true
  volumes:
  - name: docker-config
    secret:
      secretName: ecr-credentials
      items:
      - key: .dockerconfigjson
        path: config.json
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
        container('aws-cli') {
          sh '''
            echo "=== Environment Information ==="
            echo "AWS Region: ${AWS_REGION}"
            echo "ECR Registry: ${ECR_REGISTRY}"
            echo "EKS Cluster: ${EKS_CLUSTER}"
            echo "Commit ID: ${COMMIT_ID}"
            echo "Namespace: ${NAMESPACE}"
            
            aws --version
            echo "✅ Environment ready!"
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
            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
          '''
        }
        container('kubectl') {
          sh '''
            echo "=== Kubernetes Configuration ==="
            kubectl get nodes
            echo "✅ Cluster connection verified!"
          '''
        }
      }
    }
    
    stage('📦 Build Custom Images with Kaniko') {
      parallel {
        stage('🗳️ Build Frontend') {
          steps {
            container('kaniko') {
              sh """
                echo "=== Building Frontend Image (Your Flask App) ==="
                /kaniko/executor \\
                  --context=\${WORKSPACE}/frontend \\
                  --dockerfile=\${WORKSPACE}/frontend/Dockerfile \\
                  --destination=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} \\
                  --destination=${ECR_REGISTRY}/voting-app-frontend:latest \\
                  --cache=true
                echo "✅ Frontend image built and pushed!"
              """
            }
          }
        }
        
        stage('📊 Build Backend') {
          steps {
            container('kaniko') {
              sh """
                echo "=== Building Backend Image (Your Node.js App) ==="
                /kaniko/executor \\
                  --context=\${WORKSPACE}/backend \\
                  --dockerfile=\${WORKSPACE}/backend/Dockerfile \\
                  --destination=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} \\
                  --destination=${ECR_REGISTRY}/voting-app-backend:latest \\
                  --cache=true
                echo "✅ Backend image built and pushed!"
              """
            }
          }
        }
        
        stage('⚙️ Build Worker') {
          steps {
            container('kaniko') {
              sh """
                echo "=== Building Worker Image (Your .NET App) ==="
                /kaniko/executor \\
                  --context=\${WORKSPACE}/worker \\
                  --dockerfile=\${WORKSPACE}/worker/Dockerfile \\
                  --destination=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} \\
                  --destination=${ECR_REGISTRY}/voting-app-worker:latest \\
                  --cache=true
                echo "✅ Worker image built and pushed!"
              """
            }
          }
        }
      }
    }
    
    stage('✅ Verify Custom Images') {
      steps {
        container('aws-cli') {
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
    
    stage('🚀 Deploy Custom Images to EKS') {
      steps {
        container('kubectl') {
          sh '''
            echo "=== Deploying Custom Images to EKS ==="
            
            # Create namespace
            kubectl create namespace ${NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
            
            # Deploy infrastructure
            echo "Deploying infrastructure..."
            kubectl apply -f k8s/redis.yaml -n ${NAMESPACE}
            kubectl apply -f k8s/postgres.yaml -n ${NAMESPACE}
            
            # Deploy applications with custom images
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
      • Frontend: Your Flask voting app"
      • Backend: Your Node.js results app"
      • Worker: Your .NET vote processor"
      
      🚀 Commit: ${COMMIT_ID}"
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
      echo '🏁 Custom image pipeline finished.'
    }
  }
}
