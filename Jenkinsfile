pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Environment Setup') {
            steps {
                sh '''
                    echo "=== Environment Setup ==="
                    whoami
                    pwd
                    echo "Build Number: ${BUILD_NUMBER}"
                    
                    # Check if tools are available
                    docker --version || echo "Docker not found - will try to use host Docker"
                    aws --version || echo "AWS CLI not found - will install"
                    kubectl version --client || echo "kubectl not found - will install"
                '''
            }
        }
        
        stage('Install Tools') {
            steps {
                sh '''
                    echo "=== Installing AWS CLI ==="
                    if ! command -v aws &> /dev/null; then
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -o awscliv2.zip
                        sudo ./aws/install --update 2>/dev/null || ./aws/install --update 2>/dev/null || echo "AWS CLI installation attempted"
                    fi
                    
                    echo "=== Installing kubectl ==="
                    if ! command -v kubectl &> /dev/null; then
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        sudo mv kubectl /usr/local/bin/ 2>/dev/null || mv kubectl /usr/local/bin/ 2>/dev/null || echo "kubectl installation attempted"
                    fi
                    
                    echo "=== Tool Verification ==="
                    docker --version || echo "❌ Docker not available"
                    aws --version || echo "❌ AWS CLI not available"  
                    kubectl version --client || echo "❌ kubectl not available"
                '''
            }
        }
        
        stage('Checkout Code') {
            steps {
                checkout scm
                sh '''
                    echo "=== Repository Structure ==="
                    ls -la
                    find . -name "Dockerfile" -type f
                '''
            }
        }
        
        stage('Docker Setup') {
            steps {
                sh '''
                    echo "=== Docker Setup ==="
                    
                    # Try different Docker access methods
                    if docker ps >/dev/null 2>&1; then
                        echo "✅ Docker is accessible"
                    elif [ -S /var/run/docker.sock ]; then
                        echo "Docker socket found, trying to fix permissions..."
                        sudo chmod 666 /var/run/docker.sock 2>/dev/null || echo "Cannot change socket permissions"
                        sudo usermod -aG docker jenkins 2>/dev/null || echo "Cannot add user to docker group"
                    else
                        echo "❌ Docker not accessible - will use manual build instructions"
                    fi
                    
                    # Test Docker again
                    docker ps || echo "Docker still not accessible"
                '''
            }
        }
        
        stage('ECR Login') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) == 0 
                }
            }
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        echo "=== ECR Login ==="
                        aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        echo "✅ ECR Login successful"
                    '''
                }
            }
        }
        
        stage('Build Images') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) == 0 
                }
            }
            parallel {
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "=== Building Frontend ==="
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                echo "✅ Frontend image built"
                            '''
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "=== Building Backend ==="
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                echo "✅ Backend image built"
                            '''
                        }
                    }
                }
                stage('Build Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "=== Building Worker ==="
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                echo "✅ Worker image built"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) == 0 
                }
            }
            steps {
                sh '''
                    echo "=== Pushing Images to ECR ==="
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                    docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                    echo "✅ All images pushed to ECR"
                '''
            }
        }
        
        stage('Manual Build Instructions') {
            when {
                expression { 
                    return sh(script: 'docker ps', returnStatus: true) != 0 
                }
            }
            steps {
                sh '''
                    echo "=================================================="
                    echo "🚀 MANUAL BUILD INSTRUCTIONS"
                    echo "=================================================="
                    echo "Docker not accessible in Jenkins. Run these commands manually:"
                    echo ""
                    echo "1. ECR Login:"
                    echo "   aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    echo ""
                    echo "2. Build Images:"
                    echo "   cd frontend && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ."
                    echo "   cd backend && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} ."
                    echo "   cd worker && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} ."
                    echo ""
                    echo "3. Push Images:"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                    echo "=================================================="
                '''
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        echo "=== Configuring kubectl ==="
                        aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                        
                        echo "=== Updating Kubernetes Manifests ==="
                        sed -i "s|image: .*voting-app:frontend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                        sed -i "s|image: .*voting-app:backend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}|g" k8s/backend.yaml
                        sed -i "s|image: .*voting-app:worker.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}|g" k8s/worker.yaml
                        
                        echo "=== Deploying to EKS ==="
                        kubectl apply -f k8s/database.yaml
                        kubectl apply -f k8s/frontend.yaml
                        kubectl apply -f k8s/backend.yaml
                        kubectl apply -f k8s/worker.yaml
                        
                        echo "=== Waiting for deployments ==="
                        kubectl rollout status deployment/frontend --timeout=300s || true
                        kubectl rollout status deployment/backend --timeout=300s || true
                        kubectl rollout status deployment/worker --timeout=300s || true
                        
                        echo "✅ Deployment completed"
                    '''
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                sh '''
                    echo "=== Deployment Status ==="
                    kubectl get pods -o wide
                    kubectl get services
                    kubectl get deployments
                    
                    echo "=== Service URLs ==="
                    kubectl get svc -o wide
                '''
            }
        }
    }
    
    post {
        always {
            echo "=== Pipeline Cleanup ==="
            sh '''
                docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} 2>/dev/null || true
                docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} 2>/dev/null || true
                docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} 2>/dev/null || true
                docker system prune -f 2>/dev/null || true
            '''
        }
        success {
            echo "🎉 Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed - check logs above"
        }
    }
}
