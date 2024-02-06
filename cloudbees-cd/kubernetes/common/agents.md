# GKE example CloudBees CD/RO agent installation

To run user jobs within your CloudBees CD/RO environment, you must install at least one agent.

>**IMPORTANT**
>
> CloudBees CD/RO installations include a CloudBees CD/RO bound agent (`flow-bound-agent`) component. However, this agent is an internal component used specifically by CloudBees CD/RO for internal operations. While it is possible to schedule user jobs on bound agents, they are not intended for this purpose, and the overall performance of CloudBees CD/RO may be greatly impacted. CloudBees CD/RO agents should be used instead.

## Prerequisites
To complete the following instructions, you must meet the cluster and tooling requirements listed in [Prerequisites](README.md#gke-available-examples-a-namecdro-gke-available-examples).


## Configure environment variables

The commands in the following sections are preconfigured to use environment variables. To align your installation, set the following environment variables:

```bash
# If you have already set the $NAMESPACE for you CloudBees CD/RO installation, this is not needed. 
NAMESPACE=<CLOUDBEES-CD-NAMESPACE>
# If you have already set the $HELM_RELEASE for you CloudBees CD/RO installation, this is not needed. 
HELM_RELEASE=<CLOUDBEES-CD-HELM-RELEASE>
# Do not change:
AGENTS_FILE_URL="https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-agent-example.yaml"
```

## Install CloudBees CD/RO agent

The following steps are an example of installing a CloudBees CD/RO agent:

1. To download the example CloudBees CD/RO agent values file, run: 
    ```bash
    curl -fsSL -o cloudbees-cd-agent-example.yaml $AGENTS_FILE_URL
    ```

2. To add the `cloudbees` Helm repo, run:
    ```bash
    helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
    helm repo update  
    ```

3. To install the CloudBees CD/RO agent from `cloudbees/cd` Helm repo, run: 
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

## Tear down CloudBees CD/RO agent installation

Once you are finished with your CloudBees CD/RO agents, to tear down the agent installation, run:
```bash
    helm uninstall $HELM_RELEASE-agents -n $NAMESPACE
  ```  