# CloudBees Flow Examples

Files in this folder complement mentions in CloudBees Flow product documentation, found xref:latest@cloudbees-flow:ROOT:index.adoc[here].

## In this folder
This folder contains example values `.yaml` files for the CloudBees Flow Helm Chart.

- `cloudbees-flow-demo.yaml`: Example .yaml file for installing CloudBees Flow on standard Kubernetes for a non-production environment.
- `cloudbees-flow-prod.yaml`: Example .yaml file for installing CloudBees Flow on standard Kubernetes for a production environment.
- `cloudbees-flow-agent-example.yaml`: Example .yaml for a CloudBees Flow agent.
- `cloudbees-flow-agent-defaults.yaml`: Example .yaml file for installing a CloudBees Flow agent on standard Kubernetes.
- `cloudbees-flow-defaults.yaml` ( was `values.yaml`): Default parameter values for CloudBees Flow on standard Kubernetes. Springboard from this file to create your own custom values.yaml file.
- `values-filebeat.yaml`: Sample values file to configure Filebeat log shipper to capture logs from CloudBees Flow services and pods.
