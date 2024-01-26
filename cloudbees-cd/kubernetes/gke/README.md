# CloudBees CD/RO GKE example installations

This directory provides example installations of CloudBees CD/RO Helm charts within GKE clusters.

>**IMPORTANT** 
> 
>All examples provided are for informational purposes only. They are not meant to be used in production environments, but only to provide working demonstrations of such environments. 
> 
>If you use these examples in actual production environments data loss or other security-related issues may occur. For production environments, always follow the security policies and rules of your organization.  

## Pre-requisites:

You must meet these pre-requisites to follow the instructions in the examples:

- You must have the `gcloud` CLI installed. Refer to the `gcloud` [installation](https://cloud.google.com/sdk/docs/install) and [configuration](https://cloud.google.com/sdk/docs/initializing) documentation for more information.
- You must have `kubectl` CLI installed. Refer to [`kubectl` installation](https://kubernetes.io/docs/tasks/tools/#kubectl), or to install using `gcloud`, run:
     ```bash
    gcloud components install kubectl
     ```
- You must have the `helm` CLI installed. Refer to [`helm` installation](https://helm.sh/docs/intro/install/), or run:
    ```bash
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
  ```

## GKE examples

The following example installations are provided: 

* [GKE example environment and installation in demo mode](demo.md)

* [GKE example environment and installation in production mode](prod.md)

* [GKE example installation of CloudBees CD/RO agent Helm charts](agents.md)
