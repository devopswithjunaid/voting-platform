pipeline {
    agent {
        docker {
            image 'devopswithjunaid/jenkins-agent-dind:latest'
            args '--privileged -v /var/run/docker.sock:/var/run/docker.sock'
        }
    }
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'voting-app'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Verify Environment') {
            steps {
                sh '''
                    echo "=== Environment Check ==="
                    whoami
                    pwd
                    docker --version || echo "Docker not found"
                    aws --version || echo "AWS CLI not found"
                    kubectl version --client || echo "kubectl not found"
                '''
            }
        }
        
        stage('Checkout Code') {
            steps {
                checkout scm
                sh '''
                    echo "=== Repository Structure ==="
                    ls -la
                    echo "=== Checking Dockerfiles ==="
                    find . -name "Dockerfile" -type f
                '''
            }
        }
        
        stage('ECR Login') {
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
        
        stage('Deploy to EKS') {
            steps {
                withCredentials([aws(credentialsId: 'aws-credentials')]) {
                    sh '''
                        echo "=== Configuring kubectl ==="
                        aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                        
                        echo "=== Updating Kubernetes Manifests ==="
                        # Update image tags in manifests
                        sed -i "s|image: .*voting-app:frontend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}|g" k8s/frontend.yaml
                        sed -i "s|image: .*voting-app:backend.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}|g" k8s/backend.yaml
                        sed -i "s|image: .*voting-app:worker.*|image: ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}|g" k8s/worker.yaml
                        
                        echo "=== Deploying to EKS ==="
                        # Deploy database components first
                        kubectl apply -f k8s/database.yaml
                        
                        # Deploy application components
                        kubectl apply -f k8s/frontend.yaml
                        kubectl apply -f k8s/backend.yaml
                        kubectl apply -f k8s/worker.yaml
                        
                        echo "=== Waiting for deployments ==="
                        kubectl rollout status deployment/frontend --timeout=300s
                        kubectl rollout status deployment/backend --timeout=300s
                        kubectl rollout status deployment/worker --timeout=300s
                        
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
                    kubectl get svc -o wide | grep LoadBalancer || echo "No LoadBalancer services found"
                '''
            }
        }
    }
    
    post {
        always {
            echo "=== Pipeline Cleanup ==="
            sh '''
                # Clean up local Docker images
                docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                docker system prune -f || true
            '''
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
