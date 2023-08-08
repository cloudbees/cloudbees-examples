### Create a GKE cluster for CloudBees CD installation in `demo` mode

All the steps to create an environment are not a recommendation for production use.
All the steps below are optional and are for informational purposes only and are provided as an example for quickly setting up an infrastructure to install CD on k8s.
Be sure to follow the security policies and rules of your organization.

- Set environment variables
   ```bash
  GCP_ZONE=<gcp-zone>                                   # e.g. GCP_ZONE=us-east1-b
  GCP_PROJECT=<gcp-project>                             # e.g. GCP_PROJECT=cloudbees-cd-demo
  GKE_CLUSTER_NAME=<gke-cluster-name>                   # e.g. GKE_CLUSTER_NAME=gke-cd-demo
  # Number of nodes in the cluster, 2 is enough for demo purposes
  GKE_CLUSTER_NUM_NODES=<gke-cluster-number-of-nodes>   # e.g. GKE_CLUSTER_NUM_NODES=2
  # Machine type for the GKE cluster nodes, e2-standard-4 is enough for demo purposes
  GKE_CLUSTER_MACHINE_TYPE=<gke-cluster-machine-type>   # e.g. GKE_CLUSTER_MACHINE_TYPE=e2-standard-4
  HELM_RELEASE=<cloudbees-cd-helm-release>              # e.g. HELM_RELEASE=cd-demo
  NAMESPACE=<cloudbees-cd-namespace>                    # e.g. NAMESPACE=cd-demo
  ```  
- Create GKE cluster
    ```bash
    gcloud container clusters create "$GKE_CLUSTER_NAME" \
    --project="$GCP_PROJECT" \
    --num-nodes="$GKE_CLUSTER_NUM_NODES" \
    --machine-type="$GKE_CLUSTER_MACHINE_TYPE" \
    --zone="$GCP_ZONE"
  ```
### CloudBees CD Installation in `demo` mode  
- Download demo values file
  ```bash
  DEMO_FILE_URL=https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-demo.yaml
  curl -fsSL -o cloudbees-cd-demo.yaml $DEMO_FILE_URL
  ```
- Install CD from cloudbees/cd Helm repo
    ```bash
     helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
     helm repo update
  
    # Install CD Server Helm chart
     helm install $HELM_RELEASE cloudbees/cloudbees-flow \
      --namespace $NAMESPACE \
      --create-namespace \
      --values cloudbees-cd-demo.yaml \
      --wait --timeout 1000s
  ```
- Get the URL of the CD server and the generated password for `admin` user 
    ```bash
  LB_HOSTIP=$(kubectl get service $HELM_RELEASE-ingress-nginx-controller -n $NAMESPACE -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
  echo "Available at: https://$LB_HOSTIP/flow/"
  # Get your admin user password by running:
  kubectl get secret $HELM_RELEASE-cloudbees-flow-credentials \
    --namespace $NAMESPACE \
    -o jsonpath="{.data.CBF_SERVER_ADMIN_PASSWORD}" | base64 --decode; echo
  ```  

[Example of installation CD agent helm charts](agents.md)

### Cleanup

- Delete CD Server
    ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
  ```  
- Delete GKE cluster
   ```bash
   gcloud container clusters delete $GKE_CLUSTER_NAME --zone=$GCP_ZONE
  ```  
