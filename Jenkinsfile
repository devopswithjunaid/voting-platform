pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '356564030462.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'my-voting-app'
        EKS_CLUSTER = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    triggers {
        githubPush()
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'ls -la'
            }
        }
        
        stage('Test') {
            parallel {
                stage('Test Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                python3 --version
                                python3 -m py_compile app.py
                                echo "Frontend syntax check passed"
                            '''
                        }
                    }
                }
                stage('Test Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                node --version
                                npm --version
                                npm install --production
                                node -c server.js
                                echo "Backend syntax check passed"
                            '''
                        }
                    }
                }
                stage('Test Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                dotnet --version
                                dotnet restore
                                dotnet build --configuration Release --no-restore
                                echo "Worker build test passed"
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Build Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        dir('frontend') {
                            sh '''
                                echo "Building Frontend Docker image..."
                                docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} .
                                docker images | grep frontend-${IMAGE_TAG}
                            '''
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        dir('backend') {
                            sh '''
                                echo "Building Backend Docker image..."
                                docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} .
                                docker images | grep backend-${IMAGE_TAG}
                            '''
                        }
                    }
                }
                stage('Build Worker') {
                    steps {
                        dir('worker') {
                            sh '''
                                echo "Building Worker Docker image..."
                                docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} .
                                docker images | grep worker-${IMAGE_TAG}
                            '''
                        }
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                        sh '''
                            echo "Logging into ECR..."
                            aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            
                            echo "Pushing images to ECR..."
                            docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                            docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                            
                            echo "Images pushed successfully!"
                        '''
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                        sh '''
                            echo "Configuring kubectl for EKS..."
                            aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                            kubectl cluster-info
                            
                            echo "Deploying database and cache first..."
                            kubectl apply -f k8s/database.yaml
                            
                            echo "Waiting for database to be ready..."
                            kubectl wait --for=condition=available --timeout=300s deployment/db || true
                            kubectl wait --for=condition=available --timeout=300s deployment/redis || true
                            
                            echo "Updating image tags in manifests..."
                            sed -i "s|frontend-latest|frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                            sed -i "s|backend-latest|backend-${IMAGE_TAG}|g" k8s/backend.yaml
                            sed -i "s|worker-latest|worker-${IMAGE_TAG}|g" k8s/worker.yaml
                            
                            echo "Deploying application components..."
                            kubectl apply -f k8s/frontend.yaml
                            kubectl apply -f k8s/backend.yaml
                            kubectl apply -f k8s/worker.yaml
                            
                            echo "Checking rollout status..."
                            kubectl rollout status deployment/frontend --timeout=300s || echo "Frontend rollout timeout"
                            kubectl rollout status deployment/backend --timeout=300s || echo "Backend rollout timeout"
                            kubectl rollout status deployment/worker --timeout=300s || echo "Worker rollout timeout"
                            
                            echo "Deployment status:"
                            kubectl get deployments
                            kubectl get services
                            kubectl get pods
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            sh '''
                echo "Cleaning up Docker images..."
                docker system prune -f || true
            '''
        }
        success {
            echo '🎉 Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed! Check logs for details.'
        }
    }
}
