# CloudBees CD GKE examples

## In this folder

This folder contains instructions to quickly install the CloudBees CD Helm Chart on GKE cluster.

Pre-requisites:

- Install gcloud cli https://cloud.google.com/sdk/docs/install
- Configure gcloud cli https://cloud.google.com/sdk/docs/initializing
- Install kubectl https://kubernetes.io/docs/tasks/tools/install-kubectl/
    ```bash
    gcloud components install kubectl
  ```
- Install Helm https://helm.sh/docs/intro/install/
    ```bash
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
  ```

[Example of environment and installation in demo mode](demo.md)

[Example of environment and installation in production mode](prod.md)

[Example of installation CD agent helm charts](agents.md)
