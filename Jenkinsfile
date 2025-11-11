pipeline {
    agent any
    
    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '767225687948.dkr.ecr.us-west-2.amazonaws.com'
        EKS_CLUSTER = 'secure-dev-env-cluster'
        NAMESPACE = 'voting-app'
        COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
        
        // Tool paths in Jenkins master
        KUBECTL_PATH = '/var/jenkins_home/kubectl'
        AWS_PATH = '/var/jenkins_home/aws/dist/aws'
    }
    
    stages {
        stage('🔍 Environment Setup') {
            steps {
                sh '''
                    echo "=== Environment Information ==="
                    echo "AWS Region: ${AWS_REGION}"
                    echo "ECR Registry: ${ECR_REGISTRY}"
                    echo "EKS Cluster: ${EKS_CLUSTER}"
                    echo "Commit ID: ${COMMIT_ID}"
                    echo "Namespace: ${NAMESPACE}"
                    echo ""
                    
                    echo "=== Tool Verification ==="
                    ${AWS_PATH} --version
                    ${KUBECTL_PATH} version --client
                    docker --version || echo "Docker not available (using Kaniko)"
                    git --version
                    echo "✅ All tools verified!"
                '''
            }
        }
        
        stage('🔧 AWS & Kubernetes Setup') {
            steps {
                sh '''
                    echo "=== AWS Configuration ==="
                    ${AWS_PATH} sts get-caller-identity
                    
                    echo "=== Kubernetes Configuration ==="
                    ${AWS_PATH} eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER}
                    ${KUBECTL_PATH} get nodes
                    echo "✅ Cluster connection verified!"
                '''
            }
        }
        
        stage('📦 Build & Push Images') {
            parallel {
                stage('🗳️ Frontend Service') {
                    steps {
                        sh '''
                            echo "=== Building Frontend Image ==="
                            
                            # Get ECR login
                            ${AWS_PATH} ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            
                            # Build image
                            cd frontend
                            docker build -t ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} .
                            docker tag ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-frontend:latest
                            
                            # Push image
                            docker push ${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID}
                            docker push ${ECR_REGISTRY}/voting-app-frontend:latest
                            
                            echo "✅ Frontend image pushed successfully!"
                        '''
                    }
                }
                
                stage('📊 Backend Service') {
                    steps {
                        sh '''
                            echo "=== Building Backend Image ==="
                            
                            # Get ECR login
                            ${AWS_PATH} ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            
                            # Build image
                            cd backend
                            docker build -t ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} .
                            docker tag ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-backend:latest
                            
                            # Push image
                            docker push ${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID}
                            docker push ${ECR_REGISTRY}/voting-app-backend:latest
                            
                            echo "✅ Backend image pushed successfully!"
                        '''
                    }
                }
                
                stage('⚙️ Worker Service') {
                    steps {
                        sh '''
                            echo "=== Building Worker Image ==="
                            
                            # Get ECR login
                            ${AWS_PATH} ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                            
                            # Build image
                            cd worker
                            docker build -t ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} .
                            docker tag ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} ${ECR_REGISTRY}/voting-app-worker:latest
                            
                            # Push image
                            docker push ${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID}
                            docker push ${ECR_REGISTRY}/voting-app-worker:latest
                            
                            echo "✅ Worker image pushed successfully!"
                        '''
                    }
                }
            }
        }
        
        stage('✅ Verify Images') {
            steps {
                sh '''
                    echo "=== Verifying Images in ECR ==="
                    
                    echo "Frontend images:"
                    ${AWS_PATH} ecr describe-images \\
                      --repository-name voting-app-frontend \\
                      --image-ids imageTag=${COMMIT_ID} \\
                      --region ${AWS_REGION} \\
                      --query 'imageDetails[0].imageTags' || echo "Image not found"
                    
                    echo "Backend images:"
                    ${AWS_PATH} ecr describe-images \\
                      --repository-name voting-app-backend \\
                      --image-ids imageTag=${COMMIT_ID} \\
                      --region ${AWS_REGION} \\
                      --query 'imageDetails[0].imageTags' || echo "Image not found"
                    
                    echo "Worker images:"
                    ${AWS_PATH} ecr describe-images \\
                      --repository-name voting-app-worker \\
                      --image-ids imageTag=${COMMIT_ID} \\
                      --region ${AWS_REGION} \\
                      --query 'imageDetails[0].imageTags' || echo "Image not found"
                    
                    echo "✅ All images verified in ECR!"
                '''
            }
        }
        
        stage('🚀 Deploy to EKS') {
            steps {
                sh '''
                    echo "=== Deploying to EKS ==="
                    
                    # Create namespace if not exists
                    ${KUBECTL_PATH} create namespace ${NAMESPACE} --dry-run=client -o yaml | ${KUBECTL_PATH} apply -f -
                    
                    # Apply infrastructure first (Redis, PostgreSQL)
                    echo "Deploying infrastructure..."
                    ${KUBECTL_PATH} apply -f k8s/redis.yaml -n ${NAMESPACE}
                    ${KUBECTL_PATH} apply -f k8s/postgres.yaml -n ${NAMESPACE}
                    
                    # Wait for infrastructure to be ready
                    echo "Waiting for infrastructure..."
                    ${KUBECTL_PATH} wait --for=condition=ready pod -l app=redis -n ${NAMESPACE} --timeout=120s || true
                    ${KUBECTL_PATH} wait --for=condition=ready pod -l app=db -n ${NAMESPACE} --timeout=120s || true
                    
                    # Apply application deployments
                    echo "Deploying applications..."
                    ${KUBECTL_PATH} apply -f k8s/frontend.yaml -n ${NAMESPACE}
                    ${KUBECTL_PATH} apply -f k8s/backend.yaml -n ${NAMESPACE}
                    ${KUBECTL_PATH} apply -f k8s/worker.yaml -n ${NAMESPACE}
                    
                    # Update images with new commit
                    echo "Updating images with commit: ${COMMIT_ID}"
                    ${KUBECTL_PATH} set image deployment/frontend \\
                      frontend=${ECR_REGISTRY}/voting-app-frontend:${COMMIT_ID} \\
                      -n ${NAMESPACE}
                    
                    ${KUBECTL_PATH} set image deployment/backend \\
                      backend=${ECR_REGISTRY}/voting-app-backend:${COMMIT_ID} \\
                      -n ${NAMESPACE}
                    
                    ${KUBECTL_PATH} set image deployment/worker \\
                      worker=${ECR_REGISTRY}/voting-app-worker:${COMMIT_ID} \\
                      -n ${NAMESPACE}
                    
                    # Wait for rollout
                    echo "Waiting for deployments to complete..."
                    ${KUBECTL_PATH} rollout status deployment/frontend -n ${NAMESPACE} --timeout=300s
                    ${KUBECTL_PATH} rollout status deployment/backend -n ${NAMESPACE} --timeout=300s
                    ${KUBECTL_PATH} rollout status deployment/worker -n ${NAMESPACE} --timeout=300s
                    
                    # Get service information
                    echo "=== Deployment Status ==="
                    ${KUBECTL_PATH} get pods -n ${NAMESPACE}
                    ${KUBECTL_PATH} get svc -n ${NAMESPACE}
                    
                    echo ""
                    echo "=== LoadBalancer URLs ==="
                    echo "Frontend URL:"
                    ${KUBECTL_PATH} get svc frontend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
                    echo ""
                    echo "Backend URL:"
                    ${KUBECTL_PATH} get svc backend -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' || echo "LoadBalancer pending..."
                '''
            }
        }
    }
    
    post {
        success {
            sh '''
                echo ""
                echo "🎉 =================================="
                echo "✅ PIPELINE COMPLETED SUCCESSFULLY!"
                echo "=================================="
                echo ""
                echo "🎯 Commit: ${COMMIT_ID}"
                echo "🌐 Namespace: ${NAMESPACE}"
                echo ""
                echo "📱 Access your application:"
                echo "- Frontend (Voting): ${KUBECTL_PATH} get svc frontend -n voting-app"
                echo "- Backend (Results): ${KUBECTL_PATH} get svc backend -n voting-app"
                echo ""
                echo "🔍 Check status: ${KUBECTL_PATH} get all -n voting-app"
                echo ""
                echo "🚀 Your voting app is now live!"
            '''
        }
        failure {
            echo '❌ Pipeline failed! Check logs for details.'
        }
        always {
            sh '''
                # Cleanup Docker images to save space
                docker system prune -f || true
                echo "🏁 Pipeline execution finished."
            '''
        }
    }
}
