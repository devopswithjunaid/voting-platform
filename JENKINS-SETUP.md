# Jenkins CI/CD Setup Instructions

## Required Jenkins Credentials

Add these credentials in Jenkins (Manage Jenkins → Credentials):

### 1. AWS Credentials
- **ID**: `AWS_ACCESS_KEY_ID`
- **Type**: Secret text
- **Value**: Your AWS Access Key ID

- **ID**: `AWS_SECRET_ACCESS_KEY`
- **Type**: Secret text  
- **Value**: Your AWS Secret Access Key

### 2. Kubeconfig
- **ID**: `kubeconfig-credentials-id`
- **Type**: Secret file
- **File**: Upload your kubeconfig file

### 3. Docker Hub (for Jenkins agent image)
- **ID**: `docker-hub-credentials`
- **Type**: Username with password
- **Username**: `devopswithjunaid`
- **Password**: Your Docker Hub token

## Setup Steps

### Step 1: Create Jenkins Namespace & RBAC
```bash
kubectl create namespace jenkins
kubectl apply -f 01-rbac-jenkins.yaml
```

### Step 2: Build & Push Jenkins Agent Image
```bash
./build-jenkins-agent.sh
```

### Step 3: Verify ECR Repositories
```bash
aws ecr describe-repositories --region us-west-2 --repository-names voting-app-frontend voting-app-backend voting-app-worker
```

### Step 4: Create Jenkins Pipeline
1. New Item → Pipeline
2. Pipeline script from SCM
3. Git repository URL
4. Script Path: `Jenkinsfile`

## Your Current Configuration

- **ECR Registry**: `767225687948.dkr.ecr.us-west-2.amazonaws.com`
- **Region**: `us-west-2`
- **Repositories**: 
  - `voting-app-frontend`
  - `voting-app-backend` 
  - `voting-app-worker`

## Verification Commands

```bash
# Check Jenkins pods
kubectl get pods -n jenkins

# Check application deployment
kubectl get all

# Check ECR images
aws ecr list-images --repository-name voting-app-frontend --region us-west-2
```

## Troubleshooting

### Docker Daemon Issues
- Check pod logs: `kubectl logs <pod-name> -c dind -n jenkins`
- Verify privileged containers are allowed

### ECR Login Issues
- Verify AWS credentials in Jenkins
- Check ECR repository permissions

### Kubernetes Deployment Issues
- Verify kubeconfig file is correct
- Check RBAC permissions: `kubectl auth can-i create deployments --as=system:serviceaccount:jenkins:jenkins`
