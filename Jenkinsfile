pipeline {
    agent any
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        PATH = "/tmp/aws-cli:/tmp:$PATH"
    }
    
    stages {
        stage('🔍 Environment Setup') {
            steps {
                script {
                    echo "=== ENVIRONMENT SETUP ==="
                    sh '''
                        echo "📋 System Info:"
                        whoami
                        pwd
                        echo "Build: ${BUILD_NUMBER}"
                        
                        echo "🔧 Installing AWS CLI..."
                        if ! command -v aws &> /dev/null; then
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip awscliv2.zip
                            ./aws/install --bin-dir /tmp/aws-cli --install-dir /tmp/aws-cli
                            rm -rf awscliv2.zip aws/
                        fi
                        
                        echo "🔧 Installing kubectl..."
                        if ! command -v kubectl &> /dev/null; then
                            curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                            chmod +x kubectl
                            mv kubectl /tmp/kubectl
                        fi
                        
                        echo "🔧 Tools Check:"
                        docker --version || echo "❌ Docker not available - check Jenkins setup"
                        /tmp/aws-cli/aws --version || echo "❌ AWS CLI failed"
                        /tmp/kubectl version --client || echo "❌ kubectl failed"
                        
                        echo "✅ Setup completed"
                    '''
                }
            }
        }
        
        stage('📥 Checkout') {
            steps {
                checkout scm
                sh '''
                    echo "📂 Repo Info:"
                    git log --oneline -3
                    ls -la
                    find . -name "Dockerfile"
                '''
            }
        }
        
        stage('🏗️ Build Images') {
            parallel {
                stage('Frontend') {
                    steps {
                        sh '''
                            cd frontend
                            docker build -t voting-app:frontend-${BUILD_NUMBER} .
                        '''
                    }
                }
                stage('Backend') {
                    steps {
                        sh '''
                            cd backend
                            docker build -t voting-app:backend-${BUILD_NUMBER} .
                        '''
                    }
                }
                stage('Worker') {
                    steps {
                        sh '''
                            cd worker
                            docker build -t voting-app:worker-${BUILD_NUMBER} .
                        '''
                    }
                }
            }
        }
        
        stage('📤 Push to ECR') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        # ECR Login
                        /tmp/aws-cli/aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        
                        # Tag and Push
                        docker tag voting-app:frontend-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}
                        docker tag voting-app:backend-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}
                        docker tag voting-app:worker-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}
                        
                        docker push ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}
                        docker push ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}
                        docker push ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}
                    '''
                }
            }
        }
        
        stage('🚀 Deploy to EKS') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        # Update kubeconfig
                        /tmp/aws-cli/aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                        
                        # Update manifests
                        sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:frontend-.*|image: ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}|g" k8s/frontend.yaml
                        sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:backend-.*|image: ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}|g" k8s/backend.yaml
                        sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:worker-.*|image: ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}|g" k8s/worker.yaml
                        
                        # Deploy
                        /tmp/kubectl apply -f k8s/
                        /tmp/kubectl rollout status deployment/frontend
                        /tmp/kubectl rollout status deployment/backend
                        /tmp/kubectl rollout status deployment/worker
                    '''
                }
            }
        }
        
        stage('📊 Verify') {
            steps {
                sh '''
                    /tmp/kubectl get pods
                    /tmp/kubectl get svc
                '''
            }
        }
    }
    
    post {
        always {
            sh 'docker system prune -f || true'
        }
        failure {
            echo "❌ Pipeline failed! Check Docker access in Jenkins container."
        }
    }
}
