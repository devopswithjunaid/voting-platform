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
        stage('Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "✅ Code checked out successfully"
                    ls -la
                '''
            }
        }
        
        stage('Environment Check') {
            steps {
                sh '''
                    echo "=== Environment Information ==="
                    whoami
                    pwd
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "Workspace: ${WORKSPACE}"
                    
                    echo "=== Available Commands ==="
                    which git || echo "Git: Not found"
                    which curl || echo "Curl: Not found"
                    which wget || echo "Wget: Not found"
                    
                    echo "=== Repository Structure ==="
                    find . -name "Dockerfile" -type f || echo "No Dockerfiles found"
                    find . -name "*.yaml" -type f | head -5 || echo "No YAML files found"
                '''
            }
        }
        
        stage('Build Notification') {
            steps {
                sh '''
                    echo "=== BUILD STARTED ==="
                    echo "Repository: voting-app"
                    echo "Build Number: ${BUILD_NUMBER}"
                    echo "ECR Registry: ${ECR_REGISTRY}"
                    echo "EKS Cluster: ${EKS_CLUSTER_NAME}"
                    echo "========================"
                '''
            }
        }
        
        stage('Prepare Deployment') {
            steps {
                sh '''
                    echo "=== Preparing Kubernetes Manifests ==="
                    
                    if [ -d "k8s" ]; then
                        echo "Found k8s directory"
                        ls -la k8s/
                        
                        echo "=== Updating image tags in manifests ==="
                        # Create backup of original files
                        cp k8s/frontend.yaml k8s/frontend.yaml.backup || true
                        cp k8s/backend.yaml k8s/backend.yaml.backup || true
                        cp k8s/worker.yaml k8s/worker.yaml.backup || true
                        
                        # Update image tags (using sed)
                        sed -i "s|image: .*voting-app:frontend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}|g" k8s/frontend.yaml || true
                        sed -i "s|image: .*voting-app:backend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}|g" k8s/backend.yaml || true
                        sed -i "s|image: .*voting-app:worker.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}|g" k8s/worker.yaml || true
                        
                        echo "✅ Manifests updated with build ${IMAGE_TAG}"
                    else
                        echo "❌ k8s directory not found"
                    fi
                '''
            }
        }
        
        stage('Manual Instructions') {
            steps {
                sh '''
                    echo "=================================================="
                    echo "🚀 MANUAL DEPLOYMENT INSTRUCTIONS"
                    echo "=================================================="
                    echo ""
                    echo "Since Docker/AWS CLI are not available in Jenkins,"
                    echo "please run these commands manually:"
                    echo ""
                    echo "1. Build and push Docker images:"
                    echo "   cd frontend && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ."
                    echo "   cd backend && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} ."
                    echo "   cd worker && docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} ."
                    echo ""
                    echo "2. Login to ECR:"
                    echo "   aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    echo ""
                    echo "3. Push images:"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                    echo "   docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                    echo ""
                    echo "4. Deploy to EKS:"
                    echo "   aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}"
                    echo "   kubectl apply -f k8s/"
                    echo ""
                    echo "=================================================="
                    echo "✅ Jenkins pipeline completed - manual steps required"
                    echo "=================================================="
                '''
            }
        }
    }
    
    post {
        always {
            echo "=== Pipeline completed ==="
        }
        success {
            echo "✅ Pipeline successful - check manual instructions above"
        }
        failure {
            echo "❌ Pipeline failed"
        }
    }
}
