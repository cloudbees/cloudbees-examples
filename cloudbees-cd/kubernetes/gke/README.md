# CloudBees CD GKE examples

## In this folder

This folder contains instructions to quickly install the CloudBees CD Helm Chart on GKE cluster.

Pre-requisites:

- Install gcloud cli https://cloud.google.com/sdk/docs/install
- Configure gcloud cli https://cloud.google.com/sdk/docs/initializing

### Create GKE cluster
- Set environment variables

https://github.com/semiroz/cloudbees-examples/blob/870f22a043a228451fdd6d1768a5253e3d90fbe1/cloudbees-cd/kubernetes/gke/demo.env#L1-L9     

    ```bash
      # Set zone. e.g. us-east1-a
      GCP_ZONE=<zone>
  
      # Set GCP project id
      GCP_PROJECT=<project-id>

      # Set cluster name e.g. flow-demo
      GKE_CLUSTER_NAME=<cluster-name>

      # Set number of nodes. 2 nodes are are necessary and sufficient for CD/RO installation
      GKE_CLUSTER_NUM_NODES=<number-of-nodes>

      # Set machine type, e.g. n1-standard-4 is enough for demo deployment
      GKE_CLUSTER_MACHINE_TYPE=<machine-type>

- Create GKE cluster
    ```bash
      # Create cluster
      gcloud container clusters create $GKE_CLUSTER_NAME \
          --project=$GCP_PROJECT \
          --num-nodes=$GKE_CLUSTER_NUM_NODES \
          --machine-type=$GKE_CLUSTER_MACHINE_TYPE \
          --addons=GcePersistentDiskCsiDriver \
          --zone=$GCP_ZONE
  ```
### CloudBees CD Installation in `demo` mode

- Install Helm https://helm.sh/docs/intro/install/
    ```bash
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
  ```
- Install kubectl https://kubernetes.io/docs/tasks/tools/install-kubectl/
    ```bash
    gcloud components install kubectl
  ```
- Download demo values file
    ```bash
    curl -fsSL -o cloudbees-cd-demo.yaml https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-demo.yaml
  ```
- Install CD from cloudbees/cd helm repo
    ```bash
     helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
     helm repo update
  
    # Set helm release name
     HELM_RELEASE=cd-demo
  
    # Set namespace name
     NAMESPACE=cd-demo
  
    # Install CD Server
     helm install $HELM_RELEASE cloudbees/cloudbees-flow \
      --namespace $NAMESPACE \
      --create-namespace \
      --values cloudbees-cd-demo.yaml \
      --wait --timeout 1000s
  ```
- Get the URL of the CD server and the generated administrator password
    ```bash
  LB_HOSTIP=$(kubectl get service $HELM_RELEASE-ingress-nginx-controller -n $NAMESPACE -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
  echo "Available at: https://$LB_HOSTIP/flow/"
  # Get your admin user password by running:
  kubectl get secret --namespace $NAMESPACE $HELM_RELEASE-cloudbees-flow-credentials \
    -o jsonpath="{.data.CBF_SERVER_ADMIN_PASSWORD}" | base64 --decode; echo
  ```
### CloudBees CD Agent Installation
- Download agent values file
    ```bash
    curl -fsSL -o cloudbees-cd-agent-defaults.yaml https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-agent-example.yaml
  ```
- Install CD Agent from cloudbees/cd helm repo
    ```bash
    helm install $HELM_RELEASE-agents cloudbees/cloudbees-flow-agent \
      --namespace $NAMESPACE \
      --create-namespace \
      --values cloudbees-cd-agent-example.yaml \
      --set flowCredentials.existingSecret=$HELM_RELEASE-cloudbees-flow-credentials \
      --wait --timeout 1000s
  ```
### Cleanup
- Delete CD Agent
    ```bash
    helm uninstall $HELM_RELEASE-agents -n $NAMESPACE
  ```
- Delete CD Server
    ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
  ```
- Delete GKE cluster
   ```bash
   gcloud container clusters delete $GKE_CLUSTER_NAME_NAME --zone=$GCP_ZONE
  ```