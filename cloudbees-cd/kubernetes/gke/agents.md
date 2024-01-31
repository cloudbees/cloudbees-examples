# GKE example CloudBees CD/RO agent installation

To run user jobs within your CloudBees CD/RO environment, you must install at least one agent.

## Prerequisites
To complete the following instructions, you must meet the cluster and tooling requirements listed in [Prerequisites](README.md#gke-available-examples-a-namecdro-gke-available-examples).


## Configure environment variables

The commands in following sections are preconfigured to use environment variables. To align your installation, set the following environment variables:

```bash
NAMESPACE=<cloudbees-cd-namespace>
HELM_RELEASE=<cloudbees-cd-helm-release>
# Do not change:
AGENTS_FILE_URL="https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-agent-example.yaml"
```

## Install CloudBees CD/RO agent

- Download agent values file
    ```bash
    curl -fsSL -o cloudbees-cd-agent-example.yaml $AGENTS_FILE_URL
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

## Teardown CloudBees CD/RO agent installation

- Delete CD Agents
    ```bash
    helm uninstall $HELM_RELEASE-agents -n $NAMESPACE
  ```  