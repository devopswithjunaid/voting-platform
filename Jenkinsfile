pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '356564030462.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'my-voting-app'
        EKS_CLUSTER = 'secure-dev-env-cluster'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Test') {
            parallel {
                stage('Test Frontend') {
                    steps {
                        dir('frontend') {
                            sh 'python3 -m py_compile app.py'
                        }
                    }
                }
                stage('Test Backend') {
                    steps {
                        dir('backend') {
                            sh 'npm install'
                            sh 'node -c server.js'
                        }
                    }
                }
                stage('Test Worker') {
                    steps {
                        dir('worker') {
                            sh 'dotnet build --configuration Release'
                        }
                    }
                }
            }
        }
        
        stage('Build Images') {
            parallel {
                stage('Build Frontend') {
                    steps {
                        script {
                            dir('frontend') {
                                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG} ."
                            }
                        }
                    }
                }
                stage('Build Backend') {
                    steps {
                        script {
                            dir('backend') {
                                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG} ."
                            }
                        }
                    }
                }
                stage('Build Worker') {
                    steps {
                        script {
                            dir('worker') {
                                sh "docker build -t ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG} ."
                            }
                        }
                    }
                }
            }
        }
        
        stage('Push to ECR') {
            steps {
                script {
                    withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                        sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                        
                        sh "docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:frontend-${IMAGE_TAG}"
                        sh "docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:backend-${IMAGE_TAG}"
                        sh "docker push ${ECR_REGISTRY}/${ECR_REPOSITORY}:worker-${IMAGE_TAG}"
                    }
                }
            }
        }
        
        stage('Deploy to EKS') {
            steps {
                script {
                    withCredentials([aws(credentialsId: 'aws-credentials', region: "${AWS_REGION}")]) {
                        sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}"
                        
                        // Update image tags in k8s files
                        sh """
                        sed -i 's|frontend-latest|frontend-${IMAGE_TAG}|g' k8s/frontend.yaml
                        sed -i 's|backend-latest|backend-${IMAGE_TAG}|g' k8s/backend.yaml
                        sed -i 's|worker-latest|worker-${IMAGE_TAG}|g' k8s/worker.yaml
                        """
                        
                        // Apply updated manifests
                        sh """
                        kubectl apply -f k8s/frontend.yaml
                        kubectl apply -f k8s/backend.yaml
                        kubectl apply -f k8s/worker.yaml
                        
                        kubectl rollout status deployment/frontend --timeout=300s
                        kubectl rollout status deployment/backend --timeout=300s
                        kubectl rollout status deployment/worker --timeout=300s
                        """
                    }
                }
            }
        }
    }
    
    post {
        always {
            sh 'docker system prune -f'
        }
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
    }
}
