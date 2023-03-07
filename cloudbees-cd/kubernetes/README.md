# CloudBees CD examples

Files in this folder complement mentions in [CloudBees CD product documentation](https://docs.cloudbees.com/docs/cloudbees-cd/latest/), for example, [Cluster and storage requirements](https://docs.cloudbees.com/docs/cloudbees-cd/latest/install-k8s/requirements). As such, they are not standalone.

## In this folder
This folder contains example values `.yaml` files for the CloudBees CD Helm Chart.

- `cloudbees-cd-demo.yaml`: Example .yaml file for installing CloudBees CD on standard Kubernetes for a non-production environment.
- `cloudbees-cd-prod.yaml`: Example .yaml file for installing CloudBees CD on standard Kubernetes for a production environment.
- `cloudbees-cd-agent-example.yaml`: Example .yaml for a CloudBees CD agent.
- `cloudbees-cd-agent-defaults.yaml`: Example .yaml file for installing a CloudBees CD agent on standard Kubernetes.
- `cloudbees-cd-defaults.yaml` ( was `values.yaml`): Default parameter values for CloudBees CD on standard Kubernetes. Springboard from this file to create your own custom values.yaml file.
- `cloudbees-cd-demo-openshift.yaml`: Example .yaml file for installing CloudBees CD on Openshift Container Platform for a non-production environment
- `cloudbees-cd-prod-openshift.yaml`: Example .yaml file for installing CloudBees CD on Openshift Container Platform for a production environment
- `cloudbees-cd-prod-multizone.yaml`: Example .yaml file for installing CloudBees CD on standard Kubernetes for a production environment with pre-configured Gateway Agents
- `values-filebeat.yaml`: Sample values file to configure Filebeat log shipper to capture logs from CloudBees CD services and pods.
- `tune-max-map-count.yaml`: One way to set the kernel parameter `vm.max_map_count` high enough to run DevOps Insight.
