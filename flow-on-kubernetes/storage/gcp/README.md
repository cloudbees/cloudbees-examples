## Provision filestore instance on GCP

After running the script successfully, the terminal displays commands to deploy the Helm chart.

### Provisioning the filestore instance

1. Install `gcloud`, if not present already, by running these commands:
  ```shell
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] \
     http://packages.cloud.google.com/apt cloud-sdk main" |\
     sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg |\
    sudo apt-key --keyring /usr/share/keyrings
cloud.google.gpg add -
        sudo apt-get update && sudo apt-get install google-cloud-sdk
  ```
2. Configure gcloud sdk

    a. `gcloud init`
  
    b. Accept the option to sign in using your Google user account.
  
    c. In your browser, sign in to your Google user account when prompted and click **Allow** to grant permission to access Google Cloud Platform resources.

3. Create service account. 
   Service account must have `Filestore viewer` and `Filestore editor` roles.

4. Run the script

  ```shell
  ./filestore.sh --action <create|delete> \
      --project <project name> \
      --location <location like us-east1> \
      --fs-name <filestore name> \
      --fs-network <network name like default>
  ```
where:

`action`      =   `create` | `delete`

`project`     =   project name

`location`    =   Location, for example, region

`fs-name`     =   filestore name

`tier`        =   STANDARD | PREMIUM  (Optional)

`capacity`    =   size for filestore instance in gb, Mimimum 1024 (Optional)

`fs-network`  =   network name

`path`        =   filestore path, for example, `filestore` (Optional)

NOTE: `--fs-network` must be same as the GKE network otherwise NFS will not mount.

5. Deploy helm chart
  ```shell
  helm repo add stable \
    https://kubernetes-charts.storage.googleapis.com/
  helm repo update
  helm install <name> stable/nfs-client-provisioner  \
       --set nfs.server=<filestore ip address> \
       --set nfs.path=/filestore
  ```
