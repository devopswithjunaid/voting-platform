#!/bin/bash

echo "🔧 Fixing Jenkins via VPN Server..."

VPN_SERVER="35.85.108.1"
KEY_PATH="~/.ssh/secure-dev-keypair"

echo "Connecting to VPN server to fix Jenkins..."

# Commands to run on VPN server
ssh -i $KEY_PATH ubuntu@$VPN_SERVER << 'EOF'
echo "🔧 Updating kubeconfig..."
aws eks update-kubeconfig --region us-west-2 --name secure-dev-env-cluster

echo "🗑️ Deleting existing Jenkins..."
kubectl delete deployment jenkins -n jenkins || true
kubectl delete configmap jenkins-init -n jenkins || true

echo "⏳ Waiting for cleanup..."
sleep 15

echo "🚀 Deploying Jenkins with Docker support..."
cat << 'YAML' | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      nodeSelector:
        role: jenkins
      tolerations:
      - key: jenkins
        operator: Equal
        value: "true"
        effect: NoSchedule
      containers:
      - name: jenkins
        image: jenkins/jenkins:2.528.1-jdk21
        ports:
        - containerPort: 8080
        env:
        - name: JAVA_OPTS
          value: "-Djenkins.install.runSetupWizard=false"
        - name: JENKINS_ADMIN_ID
          value: "admin"
        - name: JENKINS_ADMIN_PASSWORD
          value: "SecureJenkins123!"
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        - name: docker-sock
          mountPath: /var/run/docker.sock
        - name: init-script
          mountPath: /usr/share/jenkins/ref/init.groovy.d/basic-security.groovy
          subPath: basic-security.groovy
        securityContext:
          runAsUser: 0
      volumes:
      - name: jenkins-home
        emptyDir: {}
      - name: docker-sock
        hostPath:
          path: /var/run/docker.sock
          type: Socket
      - name: init-script
        configMap:
          name: jenkins-init
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-init
  namespace: jenkins
data:
  basic-security.groovy: |
    #!groovy
    import jenkins.model.*
    import hudson.security.*
    import jenkins.security.s2m.AdminWhitelistRule

    def instance = Jenkins.getInstance()

    def hudsonRealm = new HudsonPrivateSecurityRealm(false)
    hudsonRealm.createAccount("admin", "SecureJenkins123!")
    instance.setSecurityRealm(hudsonRealm)

    def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
    strategy.setAllowAnonymousRead(false)
    instance.setAuthorizationStrategy(strategy)
    instance.save()

    Jenkins.instance.getInjector().getInstance(AdminWhitelistRule.class).setMasterKillSwitch(false)
YAML

echo "⏳ Waiting for Jenkins to be ready..."
kubectl rollout status deployment/jenkins -n jenkins --timeout=300s

echo "✅ Jenkins deployment completed!"
echo "🔍 Checking Jenkins status..."
kubectl get pods -n jenkins

echo "🐳 Testing Docker access..."
kubectl exec -n jenkins deployment/jenkins -- docker --version || echo "❌ Docker not accessible yet"

echo "🌐 Jenkins should be accessible at: http://35.85.108.1:8080"
echo "👤 Username: admin"
echo "🔑 Password: SecureJenkins123!"
EOF

echo "✅ Jenkins fix completed via VPN!"
echo "🌐 Access Jenkins at: http://35.85.108.1:8080"
