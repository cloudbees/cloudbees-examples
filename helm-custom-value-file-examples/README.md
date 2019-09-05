# CloudBees Core Helm Installation Custom Value Example

## Introduction 
These YAML files are example values files for the CloudBees Core Helm Chart.

## Examples
* `example-values.yaml`,`openshift-example-values.yaml`
    
    These files are examples of installing CloudBees Core for installing CloudBees Core on standard Kubernetes and OpenShift.
- `migration-values-example.yaml`,`openshift-migration-values-example.yaml`

    These files are example values files for standard Kubernetes and an OpenShift install. 
    The Kubernetes version assumes that an Nginx-ingress controller is already installed on your Kubernetes cluster and doesn't install it.  OpenShift does not use Ingresses; instead,  it uses routes. 
    TLS is disabled in both examples.

- `eks-tls-ingress-example.yaml`
	
	   This example demonstrates using Helm with Amazon's Elastic Kubernetes Service and an enabling TLS support on the ingress.
	
