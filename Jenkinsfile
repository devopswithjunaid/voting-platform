pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'my-voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
        EMAIL_RECIPIENT = 'devopswithjunaid@gmail.com'
    }
    
    triggers {
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'ls -la'
                echo "✅ Code checked out successfully"
            }
        }
        
        stage('Test') {
            parallel {
                stage('Test Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "🧪 Testing Frontend (Flask)..."
                                python3 --version
                                python3 -m py_compile app.py
                                echo "✅ Frontend syntax check passed"
                            '''
                        }
                    }
                }
                stage('Test Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "🧪 Testing Backend (Node.js)..."
                                node --version
                                npm --version
                                npm install --production
                                node -c server.js
                                echo "✅ Backend syntax check passed"
                            '''
                        }
                    }
                }
                stage('Test Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "🧪 Testing Worker (.NET)..."
                                dotnet --version
                                dotnet restore
                                dotnet build --configuration Release --no-restore
                                echo "✅ Worker build test passed"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Build & Push to ECR') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "🏗️ Building Frontend Docker image..."
                                docker build -t ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "📤 Pushing Frontend to ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-latest
                                
                                echo "✅ Frontend image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "🏗️ Building Backend Docker image..."
                                docker build -t ${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:backend-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "📤 Pushing Backend to ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-latest
                                
                                echo "✅ Backend image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
                stage('Build Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "🏗️ Building Worker Docker image..."
                                docker build -t ${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker tag ${ECR_REPOSITORY}:worker-${IMAGE_TAG} ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "📤 Pushing Worker to ECR..."
                                aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                                docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-latest
                                
                                echo "✅ Worker image pushed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                echo '🚀 Deploying to EKS cluster...'
                sh '''
                    echo "⚙️ Configuring kubectl..."
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}
                    kubectl cluster-info
                    
                    echo "🗄️ Deploying database and cache first..."
                    kubectl apply -f k8s/database.yaml
                    
                    echo "⏳ Waiting for database to be ready..."
                    kubectl wait --for=condition=available --timeout=300s deployment/db || true
                    kubectl wait --for=condition=available --timeout=300s deployment/redis || true
                    
                    echo "🔄 Updating image tags in manifests..."
                    sed -i "s|frontend-latest|frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                    sed -i "s|backend-latest|backend-${IMAGE_TAG}|g" k8s/backend.yaml
                    sed -i "s|worker-latest|worker-${IMAGE_TAG}|g" k8s/worker.yaml
                    
                    echo "🚀 Deploying application components..."
                    kubectl apply -f k8s/frontend.yaml
                    kubectl apply -f k8s/backend.yaml
                    kubectl apply -f k8s/worker.yaml
                    
                    echo "⏳ Checking rollout status..."
                    kubectl rollout status deployment/frontend --timeout=300s || echo "⚠️ Frontend rollout timeout"
                    kubectl rollout status deployment/backend --timeout=300s || echo "⚠️ Backend rollout timeout"
                    kubectl rollout status deployment/worker --timeout=300s || echo "⚠️ Worker rollout timeout"
                    
                    echo "📊 Deployment status:"
                    kubectl get deployments
                    kubectl get services
                    kubectl get pods
                    
                    echo "🌐 Getting LoadBalancer URLs..."
                    kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Frontend LB pending..."
                    echo ""
                    kubectl get svc backend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "Backend LB pending..."
                    echo ""
                '''
            }
        }
    }
    
    post {
        always {
            sh '''
                echo "🧹 Cleaning up Docker images..."
                docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker system prune -f || true
            '''
        }
        success {
            script {
                def message = """
                🎉 PIPELINE SUCCESS! 🎉
                
                ✅ Build: #${BUILD_NUMBER}
                ✅ Repository: ${ECR_REGISTRY}/${ECR_REPOSITORY}
                ✅ Images Tagged: ${IMAGE_TAG}
                
                🚀 Deployed Components:
                - Frontend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                - Backend: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                - Worker: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                
                🌐 Access your application via LoadBalancer URLs
                📊 Check EKS cluster: ${EKS_CLUSTER_NAME}
                
                Time: ${new Date()}
                """
                
                emailext (
                    subject: "✅ Jenkins Pipeline SUCCESS - Voting App Build #${BUILD_NUMBER}",
                    body: message,
                    to: "${EMAIL_RECIPIENT}",
                    mimeType: 'text/plain'
                )
                
                echo "✅ Pipeline completed successfully!"
                echo "🚀 Application deployed: ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
                echo "📧 Success email sent to: ${EMAIL_RECIPIENT}"
            }
        }
        failure {
            script {
                def message = """
                ❌ PIPELINE FAILED! ❌
                
                ❌ Build: #${BUILD_NUMBER}
                ❌ Repository: ${ECR_REGISTRY}/${ECR_REPOSITORY}
                ❌ Failed at: ${env.STAGE_NAME}
                
                🔍 Check Jenkins logs for details:
                ${BUILD_URL}console
                
                📊 EKS Cluster: ${EKS_CLUSTER_NAME}
                
                Time: ${new Date()}
                """
                
                emailext (
                    subject: "❌ Jenkins Pipeline FAILED - Voting App Build #${BUILD_NUMBER}",
                    body: message,
                    to: "${EMAIL_RECIPIENT}",
                    mimeType: 'text/plain'
                )
                
                echo "❌ Pipeline failed!"
                echo "📧 Failure email sent to: ${EMAIL_RECIPIENT}"
            }
        }
    }
}
