pipeline {
    agent {
        kubernetes {
            yamlFile 'jenkins-dind-pod-template.yaml'
        }
    }
    
    environment {
        AWS_DEFAULT_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        EKS_CLUSTER_NAME = 'secure-dev-env-cluster'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Wait for Docker Daemon') {
            steps {
                container('dind') {
                    sh '''
                        echo "Waiting for Docker daemon to be ready..."
                        until docker info > /dev/null 2>&1; do
                            sleep 1
                        done
                        echo "Docker daemon is ready"
                    '''
                }
            }
        }
        
        stage('Setup Tools') {
            steps {
                container('dind') {
                    sh '''
                        # Install AWS CLI
                        apk add --no-cache aws-cli curl
                        
                        # Install kubectl
                        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x kubectl
                        mv kubectl /usr/local/bin/
                        
                        # Verify tools
                        docker --version
                        aws --version
                        kubectl version --client
                    '''
                }
            }
        }
        
        stage('ECR Login') {
            steps {
                container('dind') {
                    withCredentials([aws(credentialsId: 'aws-credentials')]) {
                        sh '''
                            aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                        '''
                    }
                }
            }
        }
        
        stage('Build & Push Images') {
            parallel {
                stage('Frontend') {
                    steps {
                        container('dind') {
                            dir('frontend') {
                                sh '''
                                    docker build -t voting-app:frontend-${BUILD_NUMBER} .
                                    docker tag voting-app:frontend-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}
                                    docker push ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}
                                '''
                            }
                        }
                    }
                }
                stage('Backend') {
                    steps {
                        container('dind') {
                            dir('backend') {
                                sh '''
                                    docker build -t voting-app:backend-${BUILD_NUMBER} .
                                    docker tag voting-app:backend-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}
                                    docker push ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}
                                '''
                            }
                        }
                    }
                }
                stage('Worker') {
                    steps {
                        container('dind') {
                            dir('worker') {
                                sh '''
                                    docker build -t voting-app:worker-${BUILD_NUMBER} .
                                    docker tag voting-app:worker-${BUILD_NUMBER} ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}
                                    docker push ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}
                                '''
                            }
                        }
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                container('dind') {
                    withCredentials([aws(credentialsId: 'aws-credentials')]) {
                        sh '''
                            # Update kubeconfig
                            aws eks update-kubeconfig --region ${AWS_DEFAULT_REGION} --name ${EKS_CLUSTER_NAME}
                            
                            # Update manifests with new image tags
                            sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:frontend-.*|image: ${ECR_REGISTRY}/voting-app:frontend-${BUILD_NUMBER}|g" k8s/frontend.yaml
                            sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:backend-.*|image: ${ECR_REGISTRY}/voting-app:backend-${BUILD_NUMBER}|g" k8s/backend.yaml
                            sed -i "s|image: 767225687948.dkr.ecr.us-west-2.amazonaws.com/voting-app:worker-.*|image: ${ECR_REGISTRY}/voting-app:worker-${BUILD_NUMBER}|g" k8s/worker.yaml
                            
                            # Deploy database first
                            kubectl apply -f k8s/database.yaml
                            
                            # Deploy applications
                            kubectl apply -f k8s/frontend.yaml
                            kubectl apply -f k8s/backend.yaml
                            kubectl apply -f k8s/worker.yaml
                            
                            # Wait for deployments
                            kubectl rollout status deployment/frontend --timeout=300s
                            kubectl rollout status deployment/backend --timeout=300s
                            kubectl rollout status deployment/worker --timeout=300s
                        '''
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            steps {
                container('dind') {
                    sh '''
                        echo "=== DEPLOYMENT STATUS ==="
                        kubectl get pods
                        kubectl get svc
                        
                        echo "=== APPLICATION HEALTH ==="
                        kubectl get deployment
                    '''
                }
            }
        }
    }
    
    post {
        always {
            container('dind') {
                sh '''
                    # Cleanup local images
                    docker rmi voting-app:frontend-${BUILD_NUMBER} || true
                    docker rmi voting-app:backend-${BUILD_NUMBER} || true
                    docker rmi voting-app:worker-${BUILD_NUMBER} || true
                    docker system prune -f || true
                '''
            }
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
