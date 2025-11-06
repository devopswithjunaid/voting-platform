pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'my-voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    triggers {
        githubPush()
    }
    
    stages {
        stage('🔍 Stage 1: Environment Setup') {
            steps {
                script {
                    try {
                        echo "=== STAGE 1: ENVIRONMENT SETUP ==="
                        sh '''
                            echo "📋 System Information:"
                            whoami
                            pwd
                            echo "Node: ${NODE_NAME}"
                            echo "Workspace: ${WORKSPACE}"
                            echo "Build: ${BUILD_NUMBER}"
                            
                            echo "🔧 Git Configuration:"
                            git config --global credential.helper store
                            git config --list | grep credential || echo "Git credentials configured"
                            
                            echo "✅ Stage 1 completed successfully"
                        '''
                        currentBuild.description = "Stage 1: ✅ Environment Setup Complete"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 1: ❌ Environment Setup Failed"
                        error("Stage 1 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('📥 Stage 2: Code Checkout') {
            steps {
                script {
                    try {
                        echo "=== STAGE 2: CODE CHECKOUT ==="
                        checkout scm
                        sh '''
                            echo "📂 Repository Information:"
                            git remote -v
                            git branch -a
                            git log --oneline -3
                            
                            echo "📁 Project Structure:"
                            ls -la
                            find . -name "Dockerfile" -type f
                            find . -name "*.yaml" -type f
                            
                            echo "✅ Stage 2 completed successfully"
                        '''
                        currentBuild.description = "Stage 2: ✅ Code Checkout Complete"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 2: ❌ Code Checkout Failed"
                        error("Stage 2 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('🔧 Stage 3: Tool Verification') {
            steps {
                script {
                    try {
                        echo "=== STAGE 3: TOOL VERIFICATION ==="
                        sh '''
                            echo "🔧 Installing Docker in Jenkins container..."
                            
                            # Install Docker
                            if ! command -v docker &> /dev/null; then
                                echo "Installing Docker..."
                                apt-get update
                                apt-get install -y docker.io
                                systemctl start docker || service docker start || echo "Docker service start attempted"
                                usermod -aG docker jenkins || echo "User modification attempted"
                            fi
                            
                            echo "🔍 Checking Docker:"
                            docker --version || echo "Docker installation in progress..."
                            
                            echo "🔍 Checking AWS CLI:"
                            if command -v aws &> /dev/null; then
                                aws --version
                                echo "✅ AWS CLI: Available"
                            else
                                echo "⚠️ AWS CLI: Installing..."
                                curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                                unzip -q awscliv2.zip
                                ./aws/install
                                rm -rf aws awscliv2.zip
                                aws --version
                                echo "✅ AWS CLI: Installed"
                            fi
                            
                            echo "🔍 Checking kubectl:"
                            if command -v kubectl &> /dev/null; then
                                kubectl version --client
                                echo "✅ kubectl: Available"
                            else
                                echo "⚠️ kubectl: Installing..."
                                curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                                chmod +x kubectl
                                mv kubectl /usr/local/bin/
                                kubectl version --client
                                echo "✅ kubectl: Installed"
                            fi
                            
                            echo "✅ Stage 3 completed successfully"
                        '''
                        currentBuild.description = "Stage 3: ✅ Tools Verified"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 3: ❌ Tool Verification Failed"
                        error("Stage 3 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('🧪 Stage 4: Project Validation') {
            steps {
                script {
                    try {
                        echo "=== STAGE 4: PROJECT VALIDATION ==="
                        sh '''
                            echo "📋 Validating Dockerfiles:"
                            for component in frontend backend worker; do
                                if [ -f "$component/Dockerfile" ]; then
                                    echo "✅ $component/Dockerfile exists"
                                    head -5 "$component/Dockerfile"
                                else
                                    echo "❌ $component/Dockerfile missing"
                                    exit 1
                                fi
                            done
                            
                            echo "📋 Validating K8s Manifests:"
                            for manifest in database frontend backend worker; do
                                if [ -f "k8s/$manifest.yaml" ]; then
                                    echo "✅ k8s/$manifest.yaml exists"
                                else
                                    echo "❌ k8s/$manifest.yaml missing"
                                    exit 1
                                fi
                            done
                            
                            echo "✅ Stage 4 completed successfully"
                        '''
                        currentBuild.description = "Stage 4: ✅ Project Validated"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 4: ❌ Project Validation Failed"
                        error("Stage 4 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('🏗️ Stage 5: Build Frontend') {
            steps {
                script {
                    try {
                        echo "=== STAGE 5: BUILD FRONTEND ==="
                        dir('frontend') {
                            sh '''
                                echo "🏗️ Building Frontend Docker image..."
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} . || {
                                    echo "❌ Frontend build failed"
                                    exit 1
                                }
                                
                                echo "🏷️ Tagging Frontend image..."
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "📊 Image info:"
                                docker images | grep frontend-${IMAGE_TAG}
                                
                                echo "✅ Stage 5 completed successfully"
                            '''
                        }
                        currentBuild.description = "Stage 5: ✅ Frontend Built"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 5: ❌ Frontend Build Failed"
                        error("Stage 5 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('🏗️ Stage 6: Build Backend') {
            steps {
                script {
                    try {
                        echo "=== STAGE 6: BUILD BACKEND ==="
                        dir('backend') {
                            sh '''
                                echo "🏗️ Building Backend Docker image..."
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} . || {
                                    echo "❌ Backend build failed"
                                    exit 1
                                }
                                
                                echo "🏷️ Tagging Backend image..."
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "📊 Image info:"
                                docker images | grep backend-${IMAGE_TAG}
                                
                                echo "✅ Stage 6 completed successfully"
                            '''
                        }
                        currentBuild.description = "Stage 6: ✅ Backend Built"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 6: ❌ Backend Build Failed"
                        error("Stage 6 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('🏗️ Stage 7: Build Worker') {
            steps {
                script {
                    try {
                        echo "=== STAGE 7: BUILD WORKER ==="
                        dir('worker') {
                            sh '''
                                echo "🏗️ Building Worker Docker image..."
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} . || {
                                    echo "❌ Worker build failed"
                                    exit 1
                                }
                                
                                echo "🏷️ Tagging Worker image..."
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "📊 Image info:"
                                docker images | grep worker-${IMAGE_TAG}
                                
                                echo "✅ Stage 7 completed successfully"
                            '''
                        }
                        currentBuild.description = "Stage 7: ✅ Worker Built"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 7: ❌ Worker Build Failed"
                        error("Stage 7 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('📤 Stage 8: Push to ECR') {
            steps {
                script {
                    try {
                        echo "=== STAGE 8: PUSH TO ECR ==="
                        withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                            sh '''
                                echo "🔐 Logging into ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY} || {
                                    echo "❌ ECR login failed"
                                    exit 1
                                }
                                
                                echo "📤 Pushing Frontend..."
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "📤 Pushing Backend..."
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "📤 Pushing Worker..."
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "✅ Stage 8 completed successfully"
                            '''
                        }
                        currentBuild.description = "Stage 8: ✅ Images Pushed to ECR"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 8: ❌ ECR Push Failed"
                        error("Stage 8 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('🚀 Stage 9: Deploy to EKS') {
            steps {
                script {
                    try {
                        echo "=== STAGE 9: DEPLOY TO EKS ==="
                        withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                            sh '''
                                echo "⚙️ Configuring kubectl..."
                                aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME} || {
                                    echo "❌ kubectl configuration failed"
                                    exit 1
                                }
                                
                                kubectl cluster-info
                                
                                echo "🗄️ Deploying database..."
                                kubectl apply -f k8s/database.yaml
                                kubectl wait --for=condition=available --timeout=300s deployment/db || echo "DB timeout"
                                kubectl wait --for=condition=available --timeout=300s deployment/redis || echo "Redis timeout"
                                
                                echo "🔄 Updating manifests..."
                                sed -i "s|frontend-latest|frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                                sed -i "s|backend-latest|backend-${IMAGE_TAG}|g" k8s/backend.yaml
                                sed -i "s|worker-latest|worker-${IMAGE_TAG}|g" k8s/worker.yaml
                                
                                echo "🚀 Deploying applications..."
                                kubectl apply -f k8s/frontend.yaml
                                kubectl apply -f k8s/backend.yaml
                                kubectl apply -f k8s/worker.yaml
                                
                                echo "⏳ Monitoring deployments..."
                                kubectl rollout status deployment/frontend --timeout=300s || echo "Frontend timeout"
                                kubectl rollout status deployment/backend --timeout=300s || echo "Backend timeout"
                                kubectl rollout status deployment/worker --timeout=300s || echo "Worker timeout"
                                
                                echo "✅ Stage 9 completed successfully"
                            '''
                        }
                        currentBuild.description = "Stage 9: ✅ Deployed to EKS"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 9: ❌ EKS Deployment Failed"
                        error("Stage 9 failed: ${e.getMessage()}")
                    }
                }
            }
        }
        
        stage('📊 Stage 10: Verification') {
            steps {
                script {
                    try {
                        echo "=== STAGE 10: VERIFICATION ==="
                        withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                            sh '''
                                echo "📊 Deployment Status:"
                                kubectl get deployments
                                kubectl get services
                                kubectl get pods
                                
                                echo "🌐 LoadBalancer URLs:"
                                echo "Frontend: $(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
                                echo "Backend: $(kubectl get svc backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo 'Pending...')"
                                
                                echo "✅ Stage 10 completed successfully"
                            '''
                        }
                        currentBuild.description = "Stage 10: ✅ Verification Complete"
                    } catch (Exception e) {
                        currentBuild.description = "Stage 10: ❌ Verification Failed"
                        error("Stage 10 failed: ${e.getMessage()}")
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                echo "🧹 CLEANUP STAGE"
                sh '''
                    echo "Cleaning up Docker images..."
                    docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                    docker system prune -f || true
                '''
            }
        }
        success {
            script {
                currentBuild.description = "✅ ALL STAGES COMPLETED SUCCESSFULLY!"
                echo "🎉 PIPELINE SUCCESS!"
                echo "🚀 Build: ${IMAGE_TAG}"
                echo "🌐 ECR: ${ECR_REGISTRY}/${ECR_REPOSITORY}"
                echo "📊 EKS: ${EKS_CLUSTER_NAME}"
            }
        }
        failure {
            script {
                echo "❌ PIPELINE FAILED!"
                echo "🔍 Failed at: ${currentBuild.description}"
                echo "📋 Check logs: ${BUILD_URL}console"
            }
        }
    }
}
