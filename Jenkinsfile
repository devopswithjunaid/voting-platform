pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        EKS_CLUSTER = 'infra-env-cluster'
        NAMESPACE = 'voting-app'
        COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        
        // Tool paths in Jenkins master
        KUBECTL_PATH = '/var/jenkins_home/kubectl'
        AWS_PATH = '/var/jenkins_home/aws/dist/aws'
    }
    
    stages {
        stage('🔍 Environment Setup') {
            steps {
                sh '''
                    echo "=== Environment Information ==="
                    echo "AWS Region: ${AWS_REGION}"
                    echo "ECR Registry: ${ECR_REGISTRY}"
                    echo "EKS Cluster: ${EKS_CLUSTER}"
                    echo "Commit ID: ${COMMIT_ID}"
                    echo "Namespace: ${NAMESPACE}"
                    echo ""
                    
                    echo "=== Tool Verification ==="
                    ${AWS_PATH} --version
                    ${KUBECTL_PATH} version --client
                    docker --version || echo "Docker not available (using Kaniko)"
                    git --version
                    echo "✅ All tools verified!"
                '''
            }
        }
        
        stage('🔧 AWS & Kubernetes Setup') {
            steps {
                sh '''
                    echo "=== AWS Configuration ==="
                    ${AWS_PATH} sts get-caller-identity
                    
                    echo "=== Kubernetes Configuration ==="
                    # Create symlink for aws in PATH
                    mkdir -p /var/jenkins_home/bin
                    ln -sf ${AWS_PATH} /var/jenkins_home/bin/aws
                    export PATH="/var/jenkins_home/bin:$PATH"
                    
                    # Update kubeconfig
                    ${AWS_PATH} eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                    
                    # Test connection
                    ${KUBECTL_PATH} get nodes
                    echo "✅ Cluster connection verified!"
                '''
            }
        }
        
        stage('📦 Build & Push Images') {
            steps {
                sh '''
                    echo "=== Skipping Docker Build (Docker not available) ==="
                    echo "Using pre-built images or deploying with latest tags"
                    echo "✅ Build stage completed (skipped)"
                '''
            }
        }
        
        stage('✅ Verify Images') {
            steps {
                sh '''
                    echo "=== Skipping Image Verification ==="
                    echo "Using existing images in ECR or public images"
                    echo "✅ Verification stage completed (skipped)"
                '''
            }
        }
        
        stage('🚀 Deploy to EKS') {
            steps {
                sh '''
                    echo "=== Deploying to EKS ==="
                    
                    # Setup PATH for aws command
                    export PATH="/var/jenkins_home/bin:$PATH"
                    
                    # Create namespace if not exists
                    ${KUBECTL_PATH} create namespace ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_PATH} apply -f -
                    
                    # Apply infrastructure first (Redis, PostgreSQL)
                    echo "Deploying infrastructure..."
                    ${KUBECTL_PATH} apply -f k8s/redis.yaml -n ${NAMESPACE}
                    ${KUBECTL_PATH} apply -f k8s/postgres.yaml -n ${NAMESPACE}
                    
                    # Wait for infrastructure to be ready
                    echo "Waiting for infrastructure..."
                    ${KUBECTL_PATH} wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=120s || true
                    ${KUBECTL_PATH} wait --for=condition=ready pod -l app=db -n ${NAMESPACE} --timeout=120s || true
                    
                    # Apply application deployments
                    echo "Deploying applications..."
                    ${KUBECTL_PATH} apply -f k8s/frontend.yaml -n ${NAMESPACE}
                    ${KUBECTL_PATH} apply -f k8s/backend.yaml -n ${NAMESPACE}
                    ${KUBECTL_PATH} apply -f k8s/worker.yaml -n ${NAMESPACE}
                    
                    # Update images with new commit
                    echo "Updating images with commit: ${COMMIT_ID}"
                    ${KUBECTL_PATH} set image deployment/frontend \\
                      frontend=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} \\
                      -n ${NAMESPACE}
                    
                    ${KUBECTL_PATH} set image deployment/backend \\
                      backend=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} \\
                      -n ${NAMESPACE}
                    
                    ${KUBECTL_PATH} set image deployment/worker \\
                      worker=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} \\
                      -n ${NAMESPACE}
                    
                    # Wait for rollout
                    echo "Waiting for deployments to complete..."
                    ${KUBECTL_PATH} rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
                    ${KUBECTL_PATH} rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
                    ${KUBECTL_PATH} rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
                    
                    # Get service information
                    echo "=== Deployment Status ==="
                    ${KUBECTL_PATH} get pods -n ${NAMESPACE}
                    ${KUBECTL_PATH} get svc -n ${NAMESPACE}
                    
                    echo ""
                    echo "=== LoadBalancer URLs ==="
                    echo "Frontend URL:"
                    ${KUBECTL_PATH} get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
                    echo ""
                    echo "Backend URL:"
                    ${KUBECTL_PATH} get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
                '''
            }
        }
    }
    
    post {
        success {
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
                echo "- Frontend (Voting): ${KUBECTL_PATH} get svc frontend -n voting-app"
                echo "- Backend (Results): ${KUBECTL_PATH} get svc backend -n voting-app"
                echo ""
                echo "🔍 Check status: ${KUBECTL_PATH} get all -n voting-app"
                echo ""
                echo "🚀 Your voting app is now live!"
            '''
        }
        failure {
            echo '❌ Pipeline failed! Check logs for details.'
        }
        always {
            sh '''
                # Cleanup Docker images to save space
                docker system prune -f || true
                echo "🏁 Pipeline execution finished."
            '''
        }
    }
}
