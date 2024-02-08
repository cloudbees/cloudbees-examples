
# CloudBees CD/RO GKE example installations <a name="cdro-gke-example"/>

This directory provides example installations of CloudBees CD/RO within GKE clusters, and insight for the instructions in [CloudBees CD/RO for Google Cloud Platform (GCP)](https://docs.cloudbees.com/docs/cloudbees-cd/latest/install-k8s/k8s-platform-specific-configurations#_google_cloud_platform_gcp).

>**IMPORTANT** 
> 
>All examples provided are for informational purposes only. They are not meant to be used in production environments, but only to provide working demonstrations of such environments. 
> 
>If you use these examples in actual production environments data loss or other security-related issues may occur. For production environments, always follow the security policies and rules of your organization.  

## Prerequisites <a name="cdro-gke-example-prerequisites "/>

You must meet these pre-requisites to follow the instructions in the examples:

- You must have the `gcloud` CLI installed. Refer to the `gcloud` [installation](https://cloud.google.com/sdk/docs/install) and [configuration](https://cloud.google.com/sdk/docs/initializing) documentation for more information.
- You must have `kubectl` CLI installed. Refer to [`kubectl` installation](https://kubernetes.io/docs/tasks/tools/#kubectl), or to install using `gcloud`, run:
     ```bash
    gcloud components install kubectl
     ```
  - To verify `kubectl` is installed, run:
    ```bash
    kubectl version --client
     ```

- You must have the `helm` CLI installed. Refer to [`helm` installation](https://helm.sh/docs/intro/install/), or run:
    ```bash
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
  ```

## GKE available examples <a name="cdro-gke-available-examples"/>

The following example installations are provided: 

* [GKE example CloudBees CD/RO demo installation](demo.md)

* [GKE example CloudBees CD/RO clustered installation](clustered.md)

* [GKE example CloudBees CD/RO agent installation](../common/agents.md)
