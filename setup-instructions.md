# Jenkins DinD Setup Instructions

## Step 1: Build and Push Custom Image
```bash
# Update DockerHub username in build-and-push.sh
./build-and-push.sh
```

## Step 2: Update Pod Template
Edit `jenkins-dind-pod-template.yaml`:
- Replace `junaid123` with your DockerHub username

## Step 3: Configure Jenkins
1. Go to Jenkins → Manage Jenkins → Credentials
2. Add AWS credentials with ID: `aws-credentials`

## Step 4: Update Jenkinsfile
Edit `Jenkinsfile-dind`:
- Update `ECR_REGISTRY` with your ECR URL
- Update `EKS_CLUSTER_NAME` with your cluster name
- Update `AWS_DEFAULT_REGION` if needed

## Step 5: Use New Pipeline
Replace your current Jenkinsfile with `Jenkinsfile-dind`

## Files Created:
- ✅ Dockerfile.jenkins-agent (Custom Jenkins agent)
- ✅ jenkins-dind-pod-template.yaml (K8s pod template)
- ✅ build-and-push.sh (Build script)
- ✅ Jenkinsfile-dind (Updated pipeline)
- ✅ setup-instructions.md (This file)

Your pipeline will now have Docker, AWS CLI, and kubectl working properly!
