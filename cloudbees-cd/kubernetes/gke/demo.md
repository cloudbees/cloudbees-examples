# GKE example CloudBees CD/RO demo installation

This example provides instructions on how to set up a demo installation of CloudBees CD/RO in a GKE cluster. This environment can be used to experiment with CloudBees CD/RO, and includes the following components: 

* CloudBees CD/RO server (`flow-server`)

* CloudBees CD/RO web server (`web-server`)

* CloudBees Analytics server (`cloudbees-devopsinsight`)

* The repository server (`flow-repository`)

* A bound agent (`flow-bound-agent`), which serves as a local agent for the CloudBees CD/RO and repository servers.

* Built-in MariaDB database 
  * To install an external database, a CloudBees CD/RO enterprise license is required. For more information on licenses, refer to the CloudBees CD/RO [Licenses](https://docs.cloudbees.com/docs/cloudbees-cd/latest/set-up-cdro/licenses) documentation. 

>**IMPORTANT**
>
>All examples provided are for informational purposes only. They are not meant to be used in production environments, but only to provide working demonstrations of such environments.
>
>If you use these examples in actual production environments data loss or other security-related issues may occur. For production environments, always follow the security policies and rules of your organization.

## Prerequisites
To complete the following instructions, you must meet the cluster and tooling requirements listed in [Prerequisites](README.md#gke-available-examples-a-namecdro-gke-available-examples).

## Configure environment variables

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
  # Do not change
  DEMO_FILE_URL=https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-demo.yaml
  ``` 

## Create a GKE cluster

- Create GKE cluster
    ```bash
    gcloud container clusters create "$GKE_CLUSTER_NAME" \
    --project="$GCP_PROJECT" \
    --num-nodes="$GKE_CLUSTER_NUM_NODES" \
    --machine-type="$GKE_CLUSTER_MACHINE_TYPE" \
    --zone="$GCP_ZONE"
  ```

## Install CloudBees CD/RO demo environment
 
- Download demo values file
  ```bash
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

## Teardown CloudBees CD/RO demo installation

- Delete CD Server
    ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
  ```  
- Delete GKE cluster
   ```bash
   gcloud container clusters delete $GKE_CLUSTER_NAME --zone=$GCP_ZONE
  ```  
