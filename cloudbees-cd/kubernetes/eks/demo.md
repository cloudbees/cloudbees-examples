### Create an EKS cluster for CloudBees CD installation in `demo` mode

All the steps to create an environment are not a recommendation for production use.
All the steps below are optional and are for informational purposes only and are provided as an example for quickly setting up an infrastructure to install CD on k8s.
Be sure to follow the security policies and rules of your organization.

- Create EKS cluster by following the [eksctl documentation](https://eksctl.io/getting-started/)
- ```bash
  # Download the EKS demo.yaml file
  EKS_FILE_URL=https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/eks/cd-demo-eks.yaml
  curl -fsSL -o cd-demo-eks.yaml $EKS_FILE_URL
  
  # Set the cluster name and region
  CLUSTER=cd-demo
  REGION=us-east-1
  
  # Replace the cluster name and region in the demo.yaml file
  sed "s/<CLUSTER>/$CLUSTER/g; s/<REGION>/$REGION/g" < cd-demo-eks.yaml > $CLUSTER-$REGION-eks.yaml

  # Create the EKS cluster using eksctl
  eksctl create cluster -f $CLUSTER-$REGION-eks.yaml
  ```

### CloudBees CD Installation in `demo` mode
- Download demo values file
  ```bash
  DEMO_FILE_URL=https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-demo.yaml
  curl -fsSL -o cd-demo-helm-values.yaml $DEMO_FILE_URL
  ```
- Install CD from cloudbees/cd Helm repo
  ```bash
   helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
   helm repo update
  
  NAMESPACE=cd-demo
  HELM_RELEASE=cd-demo
  # Install CD Server Helm chart
   helm install $HELM_RELEASE cloudbees/cloudbees-flow \
    --namespace $NAMESPACE \
    --create-namespace \
    --values cd-demo-helm-values.yaml \
    --wait --timeout 1000s
  ```
- Get the URL of the CD server and the generated password for `admin` user
  ```bash
  LB_HOST=$(kubectl get service $HELM_RELEASE-ingress-nginx-controller \
    -n $NAMESPACE \
    -o jsonpath="{.status.loadBalancer.ingress[0].hostname}")
  echo "Available at: https://$LB_HOST/flow/"
  # Get your admin user password by running:
  kubectl get secret $HELM_RELEASE-cloudbees-flow-credentials \
    --namespace $NAMESPACE \
    -o jsonpath="{.data.CBF_SERVER_ADMIN_PASSWORD}" | base64 --decode; echo
  ```  

[Example of installation CD agent helm charts](../common/agents.md)

### Cleanup

- Delete CD Server
    ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
  ```  
- Delete EKS cluster
   ```bash
   eksctl delete cluster --name $CLUSTER --disable-nodegroup-eviction
  ```