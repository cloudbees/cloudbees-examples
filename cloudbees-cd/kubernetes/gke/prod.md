## CloudBees CD Installation in `production` mode

All the steps to create an environment are not a recommendation for production use.
All the steps below are optional and are for informational purposes only and are provided as an example for quickly setting up an infrastructure to install CD on k8s. 
Be sure to follow the security policies and rules of your organization.

- Set environment variables
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
  ```
### Network configuration
- Create VPC network and subnet for GKE cluster
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
- Add firewall rules for GKE cluster and RDS instance
    ```bash
    gcloud compute firewall-rules create allow-internal-$GCP_VPC_NETWORK \
      --project="$GCP_PROJECT" \
      --network=$GCP_VPC_NETWORK \
      --allow=tcp,udp,icmp \
      --source-ranges=$GCP_SUBNET_IP_RANGE
   ```
- Create an allocated range in your VPC network for the SQL instance
    ```bash
    gcloud compute addresses create google-managed-services-$GCP_VPC_NETWORK \
      --project="$GCP_PROJECT" \
      --purpose=VPC_PEERING \
      --prefix-length=20 \
      --network=$GCP_VPC_NETWORK \
      --description="Peering range for Google" \
      --global
    ```
- Create `servicenetworking.googleapis.com` peering
    ```bash
    gcloud services vpc-peerings connect \
      --service=servicenetworking.googleapis.com \
      --ranges=google-managed-services-$GCP_VPC_NETWORK \
      --network=$GCP_VPC_NETWORK \
      --project="$GCP_PROJECT"
    ```
- Create GCP service account for Filestore CSI driver
    ```bash
    GCP_SA_NAME=filestore-sa
    gcloud iam service-accounts create $GCP_SA_NAME \
      --display-name=$GCP_SA_NAME
    GCP_SA_EMAIL=$(gcloud iam service-accounts list \
      --filter="displayName:$GCP_SA_NAME" \
      --format='value(email)')
    ```
- Add Filestore editor IAM role to the service account
    ```bash
    gcloud projects add-iam-policy-binding $GCP_PROJECT \
      --member=serviceAccount:$GCP_SA_EMAIL \
      --role=roles/file.editor
    ```
### GKE cluster configuration
- Create a GKE cluster with CSI driver enabled
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
- Create custom storage class for CSI Filestore driver for provisioning filestore instance in the same network as the GKE cluster
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
### GCP SQL configuration
- Create GCP SQL instance with private connection
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
- Create new database and user
    ```bash
    GCP_DB_NAME=<gcp-db-name>
    GCP_DB_USER=<gcp-db-user>
    GCP_DB_PASSWORD=<gcp-db-password>
    gcloud sql databases create $GCP_DB_NAME \
      --instance=$GCP_DB_INSTANCE_NAME
    gcloud sql users create $GCP_DB_USER \
      --instance=$GCP_DB_INSTANCE_NAME \
      --password=$GCP_DB_PASSWORD
  ```
- Get the IP address of the database instance
    ```bash
    GCP_DB_IP=$(gcloud sql instances describe $GCP_DB_INSTANCE_NAME \
      --format='value(ipAddresses.ipAddress)')
    echo $GCP_DB_IP
  ```
- Create DNS zone
    ```bash
    GCP_DNS_ZONE=<gcp-dns-zone>                       # e.g GCP_DNS_ZONE=cd-internal
    GCP_DNS_NAME=$GCP_DNS_ZONE.
    gcloud dns managed-zones create $GCP_DNS_ZONE \
      --dns-name=$GCP_DNS_NAME \
      --description="CloudBees CD DNS zone" \
      --visibility=private \
      --networks=$GCP_VPC_NETWORK
  ```
- Create DNS record for the SQL instance
    ```bash
    DB_DNS_ADDRESS=$GCP_DB_INSTANCE_NAME.$GCP_DNS_NAME
    gcloud dns record-sets create $DB_DNS_ADDRESS \
      --zone=$GCP_DNS_ZONE \
      --type="A" \
      --ttl="300" \
      --rrdatas=$GCP_DB_IP
  ```  

### CloudBees CD installation

- Download production values file
    ```bash
    curl -fsSL -o cloudbees-cd-production.yaml https://raw.githubusercontent.com/cloudbees/cloudbees-examples/master/cloudbees-cd/kubernetes/cloudbees-cd-prod.yaml
  ```
- Create k8s namespace
    ```bash
    kubectl create namespace $NAMESPACE
  ```
- Create db credentials secret
    ```bash
    kubectl create secret generic flow-db-secret \
      --namespace $NAMESPACE \
      --from-literal=DB_USER=$GCP_DB_USER \
      --from-literal=DB_PASSWORD=$GCP_DB_PASSWORD
  ```
- Set db connection parameters in the values file
    ```yaml
    database:
      dbType: postgresql
      externalEndpoint: <DB_DNS_ADDRESS>
      dbName: <GCP_DB_NAME>
      dbPort: 5432
      existingSecret: flow-db-secret
  ```
- Install CD from cloudbees/cd Helm repo
    ```bash
    helm repo add cloudbees https://charts.cloudbees.com/public/cloudbees
    helm repo update
  
    # Install CD Server
    helm install $HELM_RELEASE cloudbees/cloudbees-flow \
      --namespace $NAMESPACE \
      --values cloudbees-cd-production.yaml \
      --set storage.volumes.serverPlugins.storageClass=filestore-sc \
      --timeout 4200s
  ```

[Example of installation CD agent helm charts](agents.md)

### Cleanup
- Delete CD Server
    ```bash
    helm uninstall $HELM_RELEASE -n $NAMESPACE
  ```  
- Delete GKE cluster
   ```bash
   gcloud container clusters delete $GKE_CLUSTER_NAME --zone=$GCP_ZONE
  ```
- Delete service account
   ```bash
   gcloud iam service-accounts delete $GCP_SA_NAME@$GCP_PROJECT.iam.gserviceaccount.com
  ```
- Delete DNS record
   ```bash
   gcloud dns record-sets delete $DB_DNS_ADDRESS \
     --zone=$GCP_DNS_ZONE \
     --type="A"
  ```
- Delete DNS zone
   ```bash
   gcloud dns managed-zones delete $GCP_DNS_ZONE
  ```
- Delete SQL instance
   ```bash
   gcloud sql instances delete $GCP_DB_INSTANCE_NAME
  ```
- Delete firewall rules
   ```bash
   gcloud compute firewall-rules delete allow-internal-$GCP_VPC_NETWORK
  ```
- Delete subnet
   ```bash
   gcloud compute networks subnets delete $GCP_VPC_SUBNET --region=$GCP_REGION
  ```
- Delete the allocated range
   ```bash
   gcloud compute addresses delete google-managed-services-$GCP_VPC_NETWORK \
    --global
  ```  
- Wait 4 days for wait period to expire service connection see https://cloud.google.com/vpc/docs/configure-private-services-access#removing-connection

- Delete private service connections
   ```bash
   gcloud services vpc-peerings delete \
    --service=servicenetworking.googleapis.com \
    --network=$GCP_VPC_NETWORK \
    --project=$GCP_PROJECT
  ```
- Delete VPC network
   ```bash
   gcloud compute networks delete $GCP_VPC_NETWORK
  ```
