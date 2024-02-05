# GKE example CloudBees CD/RO demo installation <a name="cdro-gke-example-demo"/>

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

## Prerequisites <a name="cdro-gke-example-demo-prerequisites"/>
To complete the following instructions, you must meet the cluster and tooling requirements listed in [Prerequisites](README.md#gke-available-examples-a-namecdro-gke-available-examples).

## Configure environment variables <a name="cdro-gke-example-demo-config-env-vars"/>

Commands in following sections are preconfigured to use environment variables. To align your installation, set the following environment variables:

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
  # Do not change:
  DEMO_FILE_URL="https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-demo.yaml"
``` 

## Create a GKE cluster <a name="cdro-gke-example-demo-create-gke-cluster"/>

Before you can install the CloudBees CD/RO demo, you must create a GKE cluster. To create GKE cluster, run:

>**NOTE**
>
>The following commands use variable configured in [Configure environment variables](#configure-environment-variables-a-namecdro-gke-example-demo-config-env-vars). Ensure you have configured these variables before continuing.  

```bash
gcloud container clusters create "$GKE_CLUSTER_NAME" \
--project="$GCP_PROJECT" \
--num-nodes="$GKE_CLUSTER_NUM_NODES" \
--machine-type="$GKE_CLUSTER_MACHINE_TYPE" \
--zone="$GCP_ZONE"
```
Once you have verified your GKE cluster is running, proceed to [installing CloudBees CD/RO demo](#cdro-gke-example-demo-install-cdro). 

## Install CloudBees CD/RO demo environment <a name="cdro-gke-example-demo-install-cdro"/>

The following steps are an example of installing a CloudBees demo environment:

>**NOTE**
>
>The following commands use variable configured in [Configure environment variables](#configure-environment-variables-a-namecdro-gke-example-demo-config-env-vars). Ensure you have configured these variables before continuing.

1. To download the example CloudBees CD/RO demo values file, run:
    ```bash
    curl -fsSL -o cloudbees-cd-demo.yaml $DEMO_FILE_URL
    ```
2. To install CloudBees CD/RO from the `cloudbees/cd` Helm repo, run:
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

## Log into your CloudBees CD/RO demo environment <a name="cdro-gke-example-demo-login"/>

Once CloudBees CD/RO is installed in your GKE cluster, you can access it via the instance URL using [supported browsers](https://docs.cloudbees.com/docs/cloudbees-common/latest/supported-platforms/cloudbees-ci-cloud#browsers). 

1. To get the CloudBees CD/RO instance URL, run:
    ```bash
    LB_HOSTIP=$(kubectl get service $HELM_RELEASE-ingress-nginx-controller \
    -n $NAMESPACE \
    -o jsonpath="{.status.loadBalancer.ingress[0].ip}") \
    echo "Available at: https://$LB_HOSTIP/flow/"
   ```
2. To get the autogenerated password for `admin`, run:
    ```bash
    kubectl get secret $HELM_RELEASE-cloudbees-flow-credentials \
    --namespace $NAMESPACE \
    -o jsonpath="{.data.CBF_SERVER_ADMIN_PASSWORD}" | base64 --decode; echo
    ```
3. Open your supported browser and paste the URL returned by the previous command.
4. To log in to the instance for the username, enter `admin`, and for the password, enter the autogenerated password returned from the previous command.  


## Install CloudBees CD/RO agents <a name="cdro-gke-example-demo-install-cdro-agents"/>

To run user jobs within your CloudBees CD/RO environment, you must install at least one agent. For instructions on installing CloudBees CD/RO agents, refer to [GKE example CloudBees CD/RO agent installation](agents.md).

>**IMPORTANT**
>
> CloudBees CD/RO installation include the CloudBees CD/RO bound agent (`flow-bound-agent`), but this agent is an internal component used specifically by CloudBees CD/RO for internal operations. While it is possible to schedule user jobs on bound agents, they are not intended for this purpose, and the overall performance of CloudBees CD/RO may be greatly impacted. CloudBees CD/RO agents should be used instead.

## Tear down CloudBees CD/RO demo installation <a name="cdro-gke-example-demo-teardown"/>

Once you are finished with your example CloudBees CD/RO demo installation, the following steps guide you through tearing down the environment:

>**NOTE**
>
>The following commands use variable configured in [Configure environment variables](#configure-environment-variables-a-namecdro-gke-example-demo-config-env-vars). Ensure you have configured these variables before continuing.

1. To delete the CloudBees CD/RO installation and `namespace`, run: 
   ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
    ```
2. To delete the GKE cluster, run:
   ```bash
   gcloud container clusters delete $GKE_CLUSTER_NAME --zone=$GCP_ZONE
   ``` 
