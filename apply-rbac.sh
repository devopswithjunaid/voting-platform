#!/bin/bash

echo "=== Applying Jenkins RBAC Permissions ==="
echo "This will fix the 'pods is forbidden' error"
echo ""

# Apply RBAC permissions
kubectl apply -f fix-jenkins-rbac.yaml

echo ""
echo "=== Verifying RBAC permissions ==="
kubectl auth can-i create pods --as=system:serviceaccount:jenkins:default -n jenkins
kubectl auth can-i list pods --as=system:serviceaccount:jenkins:default -n jenkins

echo ""
echo "✅ RBAC permissions applied successfully!"
echo "Jenkins should now be able to create pods for pipeline execution."
