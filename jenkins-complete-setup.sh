#!/bin/bash

echo "🔧 Complete Jenkins Setup - Restoring All Configurations..."

JENKINS_URL="http://35.85.108.1:8080"
JENKINS_USER="admin"
JENKINS_PASS="SecureJenkins123!"

echo "📋 Jenkins Setup Checklist:"
echo "================================"

echo "1. 🔐 Login Credentials:"
echo "   URL: $JENKINS_URL"
echo "   Username: $JENKINS_USER"
echo "   Password: $JENKINS_PASS"
echo ""

echo "2. 🔧 System Configuration (Manage Jenkins → Configure System):"
echo ""
echo "   Jenkins Location:"
echo "   ✅ Jenkins URL: http://10.0.3.235:31667/"
echo "   ✅ System Admin e-mail: admin@jenkins.local"
echo ""
echo "   Global properties → Environment variables:"
echo "   ✅ Name: AWS_DEFAULT_REGION"
echo "   ✅ Value: us-west-2"
echo ""
echo "   Docker (Declarative Pipeline):"
echo "   ✅ Docker registry URL: unix:///var/run/docker.sock"
echo "   ✅ Registry credentials: (leave blank)"
echo ""
echo "   Git plugin:"
echo "   ✅ Global Config user.name: Jenkins"
echo "   ✅ Global Config user.email: jenkins@local.com"
echo ""

echo "3. 🔑 Credentials Setup (Manage Jenkins → Manage Credentials → System → Global):"
echo ""
echo "   AWS Credentials:"
echo "   ✅ Kind: AWS Credentials"
echo "   ✅ ID: aws-credentials"
echo "   ✅ Access Key ID: [Your AWS Access Key]"
echo "   ✅ Secret Access Key: [Your AWS Secret Key]"
echo "   ✅ Description: AWS ECR and EKS Access"
echo ""
echo "   GitHub Credentials:"
echo "   ✅ Kind: Username with password"
echo "   ✅ Username: [Your GitHub username]"
echo "   ✅ Password: [GitHub Personal Access Token]"
echo "   ✅ ID: Github-key"
echo "   ✅ Description: GitHub Repository Access"
echo ""

echo "4. 🔌 Plugin Installation (Manage Jenkins → Manage Plugins → Available):"
echo ""
echo "   Required Plugins:"
echo "   ✅ Docker Pipeline"
echo "   ✅ AWS Steps"
echo "   ✅ Pipeline: AWS Steps"
echo "   ✅ Git"
echo "   ✅ Pipeline"
echo "   ✅ Kubernetes (optional)"
echo ""

echo "5. 📋 Pipeline Job Creation:"
echo ""
echo "   ✅ New Item → Pipeline"
echo "   ✅ Name: CI-CD for Eks"
echo "   ✅ Pipeline script from SCM"
echo "   ✅ SCM: Git"
echo "   ✅ Repository URL: https://github.com/devopswithjunaid/my-voting-app.git"
echo "   ✅ Credentials: Github-key"
echo "   ✅ Branch: */main"
echo "   ✅ Script Path: Jenkinsfile"
echo ""

echo "6. 🧪 Test Configuration:"
echo ""
echo "   ✅ Test AWS credentials in pipeline"
echo "   ✅ Test GitHub access"
echo "   ✅ Run pipeline build"
echo ""

echo "================================"
echo "🚀 Quick Setup Commands:"
echo "================================"

# Create Jenkins CLI commands for automation
cat << 'JENKINS_CONFIG' > jenkins-auto-config.groovy
import jenkins.model.*
import hudson.security.*
import com.cloudbees.plugins.credentials.*
import com.cloudbees.plugins.credentials.domains.*
import com.cloudbees.plugins.credentials.impl.*
import com.cloudbees.jenkins.plugins.awscredentials.*
import hudson.plugins.git.*

def instance = Jenkins.getInstance()

// Set Jenkins URL
def jlc = JenkinsLocationConfiguration.get()
jlc.setUrl("http://10.0.3.235:31667/")
jlc.setAdminAddress("admin@jenkins.local")
jlc.save()

// Set Git global config
def gitTool = instance.getDescriptor("hudson.plugins.git.GitTool")
def gitConfig = gitTool.getGlobalConfigName()
gitTool.setGlobalConfigName("Jenkins")
gitTool.setGlobalConfigEmail("jenkins@local.com")

// Add environment variable
def globalProps = instance.getGlobalNodeProperties()
def envVars = globalProps.get(hudson.slaves.EnvironmentVariablesNodeProperty.class)
if (envVars == null) {
    envVars = new hudson.slaves.EnvironmentVariablesNodeProperty()
    globalProps.add(envVars)
}
envVars.getEnvVars().put("AWS_DEFAULT_REGION", "us-west-2")

instance.save()
println "✅ Jenkins configuration updated!"
JENKINS_CONFIG

echo ""
echo "📝 Manual Steps Required:"
echo "1. Copy jenkins-auto-config.groovy content"
echo "2. Go to Manage Jenkins → Script Console"
echo "3. Paste and run the script"
echo "4. Add AWS and GitHub credentials manually"
echo "5. Create pipeline job"
echo ""

echo "🔗 Access Jenkins: $JENKINS_URL"
echo "👤 Login: $JENKINS_USER / $JENKINS_PASS"
echo ""
echo "✅ Setup script ready!"
