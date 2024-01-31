# CloudBees CD EKS examples

## In this folder

This folder contains instructions to quickly install the CloudBees CD Helm Chart on EKS cluster.

Pre-requisites:

- Install aws cli https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- Configure aws cli https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-configure.html#cli-configure-quickstart-config
- Install eksctl https://eksctl.io/installation/
- Install kubectl https://kubernetes.io/docs/tasks/tools/ or https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
- Install Helm https://helm.sh/docs/intro/install/ or
    ```bash
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
  ```

[Example of environment and installation in demo mode](demo.md)

[Example of environment and installation in production mode](prod.md)

[Example of installation CD agent helm charts](../common/agents.md)
