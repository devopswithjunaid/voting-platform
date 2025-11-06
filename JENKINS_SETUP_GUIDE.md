# 🚀 Complete Jenkins Setup Guide

## 🔐 Step 1: Login to Jenkins
- **URL:** http://35.85.108.1:8080
- **Username:** admin
- **Password:** SecureJenkins123!

---

## 🔧 Step 2: System Configuration

### Go to: `Manage Jenkins` → `Configure System`

#### Jenkins Location:
```
Jenkins URL: http://10.0.3.235:31667/
System Admin e-mail address: admin@jenkins.local
```

#### Global Properties → Environment variables:
```
☑ Environment variables
Name: AWS_DEFAULT_REGION
Value: us-west-2
```

#### Declarative Pipeline (Docker):
```
Docker registry URL: unix:///var/run/docker.sock
Registry credentials: (leave blank)
```

#### Git plugin:
```
Global Config user.name Value: Jenkins
Global Config user.email Value: jenkins@local.com
```

**Click "Save"**

---

## 🔑 Step 3: Credentials Setup

### Go to: `Manage Jenkins` → `Manage Credentials` → `System` → `Global credentials`

#### Add AWS Credentials:
```
Kind: AWS Credentials
ID: aws-credentials
Access Key ID: [Your AWS Access Key]
Secret Access Key: [Your AWS Secret Key]  
Description: AWS ECR and EKS Access
```

#### Add GitHub Credentials:
```
Kind: Username with password
Username: [Your GitHub username]
Password: [GitHub Personal Access Token]
ID: Github-key
Description: GitHub Repository Access
```

---

## 🔌 Step 4: Install Plugins

### Go to: `Manage Jenkins` → `Manage Plugins` → `Available`

**Search and install these plugins:**
- ☑️ Docker Pipeline
- ☑️ AWS Steps
- ☑️ Pipeline: AWS Steps
- ☑️ Git
- ☑️ Pipeline

**Click "Install without restart"**

---

## 📋 Step 5: Create Pipeline Job

### Go to Jenkins Dashboard → `New Item`

```
Item name: CI-CD for Eks
Type: Pipeline
```

### Configure Pipeline:
```
General:
Description: Three-tier voting app CI/CD pipeline

Pipeline:
Definition: Pipeline script from SCM
SCM: Git
Repository URL: https://github.com/devopswithjunaid/my-voting-app.git
Credentials: Github-key
Branch Specifier: */main
Script Path: Jenkinsfile
```

**Click "Save"**

---

## 🧪 Step 6: Test Setup

### Test Pipeline:
1. Go to `CI-CD for Eks` job
2. Click `Build Now`
3. Check console output

### Verify Credentials:
- AWS credentials should work for ECR login
- GitHub credentials should work for repository access

---

## 🚀 Quick Automation Script

### Go to: `Manage Jenkins` → `Script Console`

**Paste and run this script:**

```groovy
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

// Set Jenkins URL
def jlc = JenkinsLocationConfiguration.get()
jlc.setUrl("http://10.0.3.235:31667/")
jlc.setAdminAddress("admin@jenkins.local")
jlc.save()

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
```

---

## ✅ Checklist

- [ ] Jenkins login successful
- [ ] System configuration saved
- [ ] AWS credentials added
- [ ] GitHub credentials added
- [ ] Required plugins installed
- [ ] Pipeline job created
- [ ] Test build successful

---

## 🔗 Quick Links

- **Jenkins URL:** http://35.85.108.1:8080
- **GitHub Repo:** https://github.com/devopswithjunaid/my-voting-app.git
- **ECR Registry:** 767225687948.dkr.ecr.us-west-2.amazonaws.com

---

**🎉 After completing all steps, your Jenkins will be fully configured for CI/CD automation!**
