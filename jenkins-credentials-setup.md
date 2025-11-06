# Jenkins Credentials Setup

## Step 1: Add AWS Credentials in Jenkins

1. Go to Jenkins Dashboard
2. Click "Manage Jenkins" → "Credentials"
3. Click "System" → "Global credentials"
4. Click "Add Credentials"
5. Select "AWS Credentials" from dropdown
6. Fill in:
   - **ID**: `aws-credentials`
   - **Access Key ID**: `YOUR_AWS_ACCESS_KEY`
   - **Secret Access Key**: `YOUR_AWS_SECRET_KEY`
   - **Description**: `AWS Credentials for ECR and EKS`
7. Click "OK"

## Step 2: Create ECR Repositories

Run these commands to create ECR repositories:

```bash
aws ecr create-repository --repository-name voting-app --region us-west-2
```

## Step 3: Build and Push Jenkins Agent Image

```bash
./build-and-push.sh
```

## Step 4: Replace Jenkinsfile

Replace your current `Jenkinsfile` with `Jenkinsfile-dind`

## Ready to Run!

Your pipeline is now configured with:
- ✅ AWS Account: 767225687948
- ✅ Region: us-west-2
- ✅ EKS Cluster: secure-dev-env-cluster
- ✅ ECR Registry: 767225687948.dkr.ecr.us-west-2.amazonaws.com
- ✅ DockerHub: devopswithjunaid/jenkins-agent-dind
