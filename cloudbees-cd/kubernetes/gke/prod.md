# GKE example CloudBees CD/RO production installation

>**NOTE**
>
>To follow all steps in this example, a CloudBees CD/RO enterprise license is required. For more information on licenses, refer to the CloudBees CD/RO [Licenses](https://docs.cloudbees.com/docs/cloudbees-cd/latest/set-up-cdro/licenses) documentation.

This example provides instructions on how to set up an example production installation of CloudBees CD/RO in a GKE cluster. This environment can be used to experiment with CloudBees CD/RO, and includes the following components:

* CloudBees CD/RO server (`flow-server`)
* CloudBees CD/RO web server (`web-server`)
* CloudBees Analytics server (`cloudbees-devopsinsight`)
* The repository server (`flow-repository`)
* A bound agent (`flow-bound-agent`), which serves as a local agent for the CloudBees CD/RO and repository servers.
* External PostgresSQL database:  This example uses PostgresSQL v13. To view all compatible databases, refer to [Supported databases for CloudBees CD/RO](https://docs.cloudbees.com/docs/cloudbees-common/latest/supported-platforms/cloudbees-cd-k8s#database-plat).
  >**IMPORTANT**
  > 
  >You must have a CloudBees CD/RO enterprise license to configure an external database.
* Additionally, a GKE cluster is also configured as part of this example. 

>**IMPORTANT**
>
>All examples provided are for informational purposes only. They are not meant to be used in production environments, but only to provide working demonstrations of such environments.
>
>If you use these examples in actual production environments data loss or other security-related issues may occur. For production environments, always follow the security policies and rules of your organization.

## Prerequisites
To complete the following instructions, you must meet the cluster and tooling requirements listed in [Prerequisites](README.md#gke-available-examples-a-namecdro-gke-available-examples).

## Configure environment variables

The commands in following sections are preconfigured to use environment variables. To align your installation, set the following environment variables:

```bash
  GCP_PROJECT=<gcp-project>                             # e.g. GCP_PROJECT=cloudbees-cd-prod
  GCP_REGION=<gcp-region>                               # e.g. GCP_REGION=us-east1
  GCP_ZONE=<gcp-zone>                                   # e.g. GCP_ZONE=us-east1-b
  GCP_VPC_NETWORK=<gcp-vpc-network>                     # e.g. GCP_VPC_NETWORK=cd-vpc
  GCP_VPC_SUBNET=<gcp-vpc-subnet>                       # e.g. GCP_VPC_SUBNET=cd-subnet
  GCP_SUBNET_IP_RANGE=<gcp-subnet-ip-range>             # e.g. GCP_SUBNET_IP_RANGE=10.0.0.0/24
  GKE_CLUSTER_NAME=<gke-cluster-name>                   # e.g. GKE_CLUSTER_NAME=gke-cd-prod
  # Number of nodes in the cluster, 3 is enough for production purposes
  GKE_CLUSTER_NUM_NODES=<gke-cluster-number-of-nodes>   # e.g. GKE_CLUSTER_NUM_NODES=3
  # Machine type for the GKE cluster nodes, n1-standard-8 is enough for production purposes
  GKE_CLUSTER_MACHINE_TYPE=<gke-cluster-machine-type>   # e.g. GKE_CLUSTER_MACHINE_TYPE=n1-standard-8
  HELM_RELEASE=<cloudbees-cd-helm-release>              # e.g. HELM_RELEASE=cd-prod
  NAMESPACE=<cloudbees-cd-namespace>                    # e.g. NAMESPACE=cd-prod
  # Do not change:
   PROD_FILE_URL="https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-prod.yaml"
```

## Configure cluster networking
 
For production environments, networking is an extremely important aspect of how CloudBees CD/RO operates. The following steps demonstrate an example of GKE cluster networking for CloudBees CD/RO: 

1. To create a VPC network and subnet for your GKE cluster, run:
    ```bash
    gcloud compute networks create $GCP_VPC_NETWORK \
      --project="$GCP_PROJECT" \
      --subnet-mode=custom \
      --bgp-routing-mode=regional
    gcloud compute networks subnets create $GCP_VPC_SUBNET \
      --project="$GCP_PROJECT" \
      --network=$GCP_VPC_NETWORK \
      --region=$GCP_REGION \
      --range=$GCP_SUBNET_IP_RANGE \
      --stack-type=IPV4_ONLY \
      --enable-private-ip-google-access
    ```
2. To add firewall rules for your GKE cluster and RDS instance, run:
    ```bash
    gcloud compute firewall-rules create allow-internal-$GCP_VPC_NETWORK \
      --project="$GCP_PROJECT" \
      --network=$GCP_VPC_NETWORK \
      --allow=tcp,udp,icmp \
      --source-ranges=$GCP_SUBNET_IP_RANGE
   ```
3. To create an allocated range in your VPC network for the SQL instance, run:
    ```bash
    gcloud compute addresses create google-managed-services-$GCP_VPC_NETWORK \
      --project="$GCP_PROJECT" \
      --purpose=VPC_PEERING \
      --prefix-length=20 \
      --network=$GCP_VPC_NETWORK \
      --description="Peering range for Google" \
      --global
    ```
4. To enable `servicenetworking.googleapis.com` peering, run:
    ```bash
    gcloud services vpc-peerings connect \
      --service=servicenetworking.googleapis.com \
      --ranges=google-managed-services-$GCP_VPC_NETWORK \
      --network=$GCP_VPC_NETWORK \
      --project="$GCP_PROJECT"
    ```
5. Create GCP service account for filestore CSI driver:
    ```bash
    GCP_SA_NAME=filestore-sa
    gcloud iam service-accounts create $GCP_SA_NAME \
      --display-name=$GCP_SA_NAME
    GCP_SA_EMAIL=$(gcloud iam service-accounts list \
      --filter="displayName:$GCP_SA_NAME" \
      --format='value(email)')
    ```
6. Add the filestore editor IAM role to the service account:
    ```bash
    gcloud projects add-iam-policy-binding $GCP_PROJECT \
      --member=serviceAccount:$GCP_SA_EMAIL \
      --role=roles/file.editor
    ```
## Create a GKE cluster

The next steps in this example demonstrate how to create a GKE cluster, which includes the CSI driver for managing network file storage:     

1. Create a GKE cluster with CSI driver enabled:
    ```bash
    gcloud container clusters create "$GKE_CLUSTER_NAME" \
    --project="$GCP_PROJECT" \
    --network=$GCP_VPC_NETWORK \
    --subnetwork=$GCP_VPC_SUBNET \
    --num-nodes="$GKE_CLUSTER_NUM_NODES" \
    --machine-type="$GKE_CLUSTER_MACHINE_TYPE" \
    --addons=GcpFilestoreCsiDriver \
    --service-account="$GCP_SA_EMAIL" \
    --zone="$GCP_ZONE"
    ```
2. Create a custom storage class for the CSI Filestore driver to provision filestore instances in the same network as the GKE cluster:
    ```bash
    cat <<EOF | kubectl apply -f -
    apiVersion: storage.k8s.io/v1
    kind: StorageClass
    metadata:
      name: filestore-sc
    provisioner: filestore.csi.storage.gke.io
    parameters:
      tier: standard
      network: projects/$GCP_PROJECT/global/networks/$GCP_VPC_NETWORK
    volumeBindingMode: Immediate
    allowVolumeExpansion: true
    EOF
    ```
  
## Configure a GCP SQL instance 

The next steps in this example demonstrate how to configure the Cloud SQL instance for your GKE cluster. This example uses PostgresSQL. For more information on the configurations in this example, refer the [Cloud SQL](https://cloud.google.com/sql/docs/postgres/instance-settings) documentation. To get started:

1. Create the GCP SQL instance with private connection:
    ```bash
    GCP_DB_INSTANCE_NAME=<gcp-db-instance-name>
    DB_ROOT_PASSWORD=$(openssl rand -base64 32)
    gcloud beta sql instances create $GCP_DB_INSTANCE_NAME \
      --database-version=POSTGRES_13 \
      --network=$GCP_VPC_NETWORK \
      --no-assign-ip \
      --no-require-ssl \
      --storage-type=SSD \
      --storage-size=10 \
      --storage-auto-increase \
      --tier=db-custom-2-7680 \
      --zone=$GCP_ZONE \
      --root-password=$DB_ROOT_PASSWORD \
      --database-flags=max_connections=1000 \
      --allocated-ip-range-name=google-managed-services-$GCP_VPC_NETWORK
    ```

2. Create a new database and user, and supply a password:
    ```bash
   # Replace <GCP-DB-NAME> with your database name:
    GCP_DB_NAME=<GCP-DB-NAME>
   # Replace <GCP-DB-USER> with your database user:                       
    GCP_DB_USER=<GCP-DB-USER>
   # Replace <GCP-DB-PASSWORD> with the user password:
    GCP_DB_PASSWORD=<GCP-DB-PASSWORD>
    gcloud sql databases create $GCP_DB_NAME \
      --instance=$GCP_DB_INSTANCE_NAME
    gcloud sql users create $GCP_DB_USER \
      --instance=$GCP_DB_INSTANCE_NAME \
      --password=$GCP_DB_PASSWORD
    ```
   
3. Get the IP address of the database instance:
    ```bash
    GCP_DB_IP=$(gcloud sql instances describe $GCP_DB_INSTANCE_NAME \
      --format='value(ipAddresses.ipAddress)')
    echo $GCP_DB_IP
    ```
   
4. Create the DNS zone:
    ```bash
    # Replace <GCP-DNS-ZONE> with the DNS zone, e.g GCP_DNS_ZONE=cd-internal.
    GCP_DNS_ZONE=<GCP-DNS-ZONE> 
    GCP_DNS_NAME=$GCP_DNS_ZONE
    gcloud dns managed-zones create $GCP_DNS_ZONE \
      --dns-name=$GCP_DNS_NAME \
      --description="CloudBees CD DNS zone" \
      --visibility=private \
      --networks=$GCP_VPC_NETWORK
    ```
   
5. Create DNS record for the SQL instance:
    ```bash
    DB_DNS_ADDRESS=$GCP_DB_INSTANCE_NAME.$GCP_DNS_NAME
    gcloud dns record-sets create $DB_DNS_ADDRESS \
      --zone=$GCP_DNS_ZONE \
      --type="A" \
      --ttl="300" \
      --rrdatas=$GCP_DB_IP
    ```  
   
Now that your cluster database is configured, you can install CloudBees CD/RO.

## Install CloudBees CD/RO production environment

Now that your cluster database is configured, you can install CloudBees CD/RO. To get started:

1. Download production values file:
    ```bash
    curl -fsSL -o cloudbees-cd-demo.yaml $PROD_FILE_URL
    ```
2.  Create Kubernetes `namespace`:
    ```bash
    kubectl create namespace $NAMESPACE
    ```
3. Create the database credentials secret:
    ```bash
    kubectl create secret generic flow-db-secret \
      --namespace $NAMESPACE \
      --from-literal=DB_USER=$GCP_DB_USER \
      --from-literal=DB_PASSWORD=$GCP_DB_PASSWORD
    ```
4.  Open `cloudbees-cd-demo.yaml` and set the following database connection parameters:
    ```yaml
    database:
      dbType: postgresql
      externalEndpoint: <DB_DNS_ADDRESS>
      dbName: <GCP_DB_NAME>
      dbPort: 5432
      existingSecret: flow-db-secret
    ```
5. Create the server `admin` secret: 
    ```bash
    CD_SERVER_ADMIN_PASSWORD=<your-password-for-admin-user>
    kubectl create secret generic $HELM_RELEASE-cloudbees-flow-credentials \
      --namespace $NAMESPACE \
      --from-literal=CBF_SERVER_ADMIN_PASSWORD=$CD_SERVER_ADMIN_PASSWORD
    ```
6.  Install CloudBee CD/RO from the `cloudbees-cd` Helm repo: 
    ```bash
    LICENSE=<relative-or-absolute-path-to-license-file>  # e.g LICENSE=~/cd/cloudbees-flow-license.xml
  
    helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
    helm repo update
  
    # Install CD Server
    helm install $HELM_RELEASE cloudbees/cloudbees-flow \
      --namespace $NAMESPACE \
      --values cloudbees-cd-production.yaml \
      --flowCredentials.existingSecret=$HELM_RELEASE-cloudbees-flow-credentials \
      --set storage.volumes.serverPlugins.storageClass=filestore-sc \
      --set-file flowLicense.licenseData=$LICENSE \
      --timeout 4200s
    ```

## Install CloudBees CD/RO agents

To run user jobs within your CloudBees CD/RO environment, you must install at least one agent. For instructions on installing CloudBees CD/RO agents, refer to [GKE example CloudBees CD/RO agent installation](agents.md).

>**IMPORTANT**
>
> CloudBees CD/RO installation include the CloudBees CD/RO bound agent (`flow-bound-agent`), but this agent is an internal component used specifically by CloudBees CD/RO for internal operations. While it is possible to schedule user jobs on bound agents, they are not intended for this purpose, and the overall performance of CloudBees CD/RO may be greatly impacted. CloudBees CD/RO agents should be used instead.

## Tear down CloudBees CD/RO production installation

Once you are finished with your example CloudBees CD/RO production installation, the following steps guide you through tearing down the environment:

>**NOTE**
>
>The following commands use variable configured in [Configure environment variables](#configure-environment-variables-a-namecdro-gke-example-demo-config-env-vars). Ensure you have configured these variables before continuing.

1. Delete the CloudBees CD/RO instance:
    ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
   ```  
2. Delete the xGKE cluster:
   ```bash
   gcloud container clusters delete $GKE_CLUSTER_NAME --zone=$GCP_ZONE
   ```
3. Delete the service account:
   ```bash
   gcloud iam service-accounts delete $GCP_SA_NAME@$GCP_PROJECT.iam.gserviceaccount.com
   ```
4. Delete the DNS record:
   ```bash
   gcloud dns record-sets delete $DB_DNS_ADDRESS \
     --zone=$GCP_DNS_ZONE \
     --type="A"
   ```
5. Delete DNS zone:
   ```bash
   gcloud dns managed-zones delete $GCP_DNS_ZONE
   ```
6. Delete the SQL instance:
   ```bash
   gcloud sql instances delete $GCP_DB_INSTANCE_NAME
   ```
7. Delete the firewall rules:
   ```bash
   gcloud compute firewall-rules delete allow-internal-$GCP_VPC_NETWORK
   ```
8. Delete the subnet:
   ```bash
   gcloud compute networks subnets delete $GCP_VPC_SUBNET --region=$GCP_REGION
   ```
9. Delete the allocated range:
   ```bash
   gcloud compute addresses delete google-managed-services-$GCP_VPC_NETWORK \
    --global
   ```

10. Delete the private service connections:
   ```bash
   gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=$GCP_VPC_NETWORK \
    --project=$GCP_PROJECT
  ```
   >**NOTE**
   >
   > When deleting private connections, you will receive a success response. However, the service waits for four days before deleting the service producer resources. For more information, refer to the [VPC Delete a private connection](https://cloud.google.com/vpc/docs/configure-private-services-access#removing-connection) documentation.
11. Delete the VPC network: 
   ```bash
   gcloud compute networks delete $GCP_VPC_NETWORK
   ```
