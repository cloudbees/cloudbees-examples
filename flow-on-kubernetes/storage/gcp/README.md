## Script will be used to provision filestore instance. 
 
After running script successfully terminal will display commands to deploy helm chart.

### Steps:

####    1) install gcloud if not present already
        a) echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
        b) curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
        c) sudo apt-get update && sudo apt-get install google-cloud-sdk

####    2) Configure gcloud sdk
        a) gcloud init
        b) Accept the option to log in using your Google user account
        c) In your browser, log in to your Google user account when prompted and click Allow to grant permission to access Google Cloud Platform resources

####    3) Create service account
        a) Service account should have Filestore viewer and Filestore editor roles.

####    4) Run the script
        a) ./filestore.sh --action <create|delete> --project <project name> --location <location like us-east1> --fs-name <filestore name> --fs-network <network name like default>"

        Where:
            action      =   create | delete
            project     =   project name
            location    =   Location i.e. region
            fs-name     =   filestore name
            tier        =   STANDARD | PREMIUM  (Optional)
            capacity    =   size for filestore instance in gb, Mimimum 1024 (Optional)
            fs-network  =   network name
            path        =   filestore path i.e. filestore (Optional)

        Note: -fs-network should be same as gke network otherwise nfs will not mount. 
        
####    5) Deploy helm chart
        helm repo add stable https://kubernetes-charts.storage.googleapis.com/
        helm repo update
        helm install <name> stable/nfs-client-provisioner  --set nfs.server=<filestore ip address> --set nfs.path=/filestore
