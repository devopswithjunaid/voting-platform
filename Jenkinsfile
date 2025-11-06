pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-dind-pod-template.yaml'
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
                container('dind') {
                    sh '''
                        echo "=== Environment Check ==="
                        whoami
                        pwd
                        echo "Build Number: ${BUILD_NUMBER}"
                        
                        echo "=== Tool Versions ==="
                        docker --version
                        aws --version
                        kubectl version --client
                        
                        echo "=== Docker Test ==="
                        docker ps
                    '''
                }
            }
        }
        
        stage('Checkout Code') {
            steps {
                container('dind') {
                    checkout scm
                    sh '''
                        echo "=== Repository Structure ==="
                        ls -la
                        find . -name "Dockerfile" -type f
                    '''
                }
            }
        }
        
        stage('ECR Login') {
            steps {
                container('dind') {
                    withCredentials([aws(credentialsId: 'aws-credentials')]) {
                        sh '''
                            echo "=== ECR Login ==="
                            aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            echo "✅ ECR Login successful"
                        '''
                    }
                }
            }
        }
        
        stage('Build Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        container('dind') {
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
                }
                stage('Build Backend') {
                    steps {
                        container('dind') {
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
                }
                stage('Build Worker') {
                    steps {
                        container('dind') {
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
        }
        
        stage('Push to ECR') {
            steps {
                container('dind') {
                    sh '''
                        echo "=== Pushing Images to ECR ==="
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}
                        docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}
                        echo "✅ All images pushed to ECR"
                    '''
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                container('dind') {
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
        }
        
        stage('Verify Deployment') {
            steps {
                container('dind') {
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
    }
    
    post {
        always {
            container('dind') {
                echo "=== Pipeline Cleanup ==="
                sh '''
                    docker rmi ${ECR_REPOSITORY}:frontend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REPOSITORY}:backend-${IMAGE_TAG} || true
                    docker rmi ${ECR_REPOSITORY}:worker-${IMAGE_TAG} || true
                    docker system prune -f || true
                '''
            }
        }
        success {
            echo "🎉 Complete CI/CD Pipeline successful! Application deployed to EKS!"
        }
        failure {
            echo "❌ Pipeline failed - check logs above"
        }
    }
}
