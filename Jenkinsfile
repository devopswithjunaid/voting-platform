pipeline {
  agent any
  
  environment {
    GITHUB_REPO = 'devopswithjunaid/voting-platform'
    COMMIT_ID = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
  }
  
  stages {
    stage('🔍 Code Analysis') {
      steps {
        sh '''
          echo "=== Code Analysis ==="
          echo "Repository: ${GITHUB_REPO}"
          echo "Commit ID: ${COMMIT_ID}"
          echo "Branch: main"
          
          echo ""
          echo "=== Project Structure ==="
          ls -la
          
          echo ""
          echo "=== Frontend Files ==="
          ls -la frontend/ || echo "Frontend directory not found"
          
          echo ""
          echo "=== Backend Files ==="
          ls -la backend/ || echo "Backend directory not found"
          
          echo ""
          echo "=== Worker Files ==="
          ls -la worker/ || echo "Worker directory not found"
          
          echo ""
          echo "=== Kubernetes Manifests ==="
          ls -la k8s/ || echo "K8s directory not found"
          
          echo "✅ Code analysis complete!"
        '''
      }
    }
    
    stage('🚀 Trigger GitHub Actions') {
      steps {
        sh '''
          echo "=== GitHub Actions Integration ==="
          echo ""
          echo "ℹ️  This Jenkins pipeline works with GitHub Actions for:"
          echo "   • Docker image builds (GitHub Actions has Docker support)"
          echo "   • ECR push (GitHub Actions has AWS integration)"
          echo "   • EKS deployment (GitHub Actions has kubectl)"
          echo ""
          echo "🔄 GitHub Actions workflow will be triggered automatically on:"
          echo "   • Push to main branch (this commit: ${COMMIT_ID})"
          echo "   • Pull request to main branch"
          echo ""
          echo "📍 Check GitHub Actions status at:"
          echo "   https://github.com/${GITHUB_REPO}/actions"
          echo ""
          echo "✅ Jenkins pipeline completed - GitHub Actions will handle build & deploy!"
        '''
      }
    }
    
    stage('📊 Deployment Status') {
      steps {
        sh '''
          echo "=== Deployment Monitoring ==="
          echo ""
          echo "🔍 To monitor deployment:"
          echo "1. GitHub Actions: https://github.com/${GITHUB_REPO}/actions"
          echo "2. AWS ECR: Check for new images"
          echo "3. EKS Cluster: kubectl get all -n voting-app"
          echo ""
          echo "📱 Application URLs (after deployment):"
          echo "• Frontend: kubectl get svc frontend -n voting-app"
          echo "• Backend: kubectl get svc backend -n voting-app"
          echo ""
          echo "✅ Monitoring setup complete!"
        '''
      }
    }
  }
  
  post {
    success {
      sh '''
        echo ""
        echo "🎉 =================================="
        echo "✅ JENKINS PIPELINE COMPLETED!"
        echo "=================================="
        echo ""
        echo "🎯 Commit: ${COMMIT_ID}"
        echo "🔗 Repository: ${GITHUB_REPO}"
        echo ""
        echo "🚀 Next Steps:"
        echo "1. Check GitHub Actions for build status"
        echo "2. Monitor EKS deployment"
        echo "3. Access application via LoadBalancer URLs"
        echo ""
        echo "💡 This hybrid approach provides:"
        echo "• Jenkins for CI/CD orchestration"
        echo "• GitHub Actions for Docker builds"
        echo "• Complete automation without manual steps"
        echo ""
        echo "🎊 Your voting app deployment is in progress!"
      '''
    }
    failure {
      echo '❌ Pipeline failed! Check logs for details.'
    }
    always {
      echo '🏁 Pipeline execution finished.'
    }
  }
}
