### CloudBees CD Agents Installation
- Download agent values file
    ```bash
    curl -fsSL -o cloudbees-cd-agent-example.yaml https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-agent-example.yaml
  ```
- Set environment variables
    ```bash
     NAMESPACE=<cloudbees-cd-namespace>
     HELM_RELEASE=<cloudbees-cd-helm-release>
    ```

- Add cloudbees helm repo
  ```bash
  helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
  helm repo update  
  ```

- Install CD Agent from cloudbees/cd helm repo
  ```bash
  # Create CD user secret
  kubectl create secret generic cd-user-secret \
   --namespace $NAMESPACE \
   --from-literal=CBF_SERVER_USER='admin' \
   --from-literal=CBF_SERVER_PASSWORD=$(kubectl get secret \
     --namespace $NAMESPACE $HELM_RELEASE-cloudbees-flow-credentials \
     -o jsonpath="{.data.CBF_SERVER_ADMIN_PASSWORD}" | base64 --decode)
  
  # Install CD Agent
  helm install $HELM_RELEASE-agents cloudbees/cloudbees-flow-agent \
    --namespace $NAMESPACE \
    --values cloudbees-cd-agent-example.yaml \
    --set flowCredentials.existingSecret=cd-user-secret \
    --wait --timeout 1000s
  ```  