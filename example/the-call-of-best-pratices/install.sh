#!/bin/bash

#### and to access the AKS cluster
ARM_CLIENT_ID=
ARM_CLIENT_SECRET=
ARM_SUBSCRIPTION_ID=
ARM_TENANT_ID=

## Install AzureCLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)"


## Install Kubernetes CLI
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
## Test installation
kubectl version --client

## Uncomment to enable bash auto completion
# source <(kubectl completion bash)

## Login to Azure with service principal you have for the terraform authorization or your own username/password
az login --service-principal -u $ARM_CLIENT_ID -p $ARM_CLIENT_SECRET --tenant $ARM_TENANT_ID

## Get the Kubeconfig
az aks get-credentials --name aks-my-cluster \
    --resource-group rg-private-aks-demo \
    --subscription $ARM_SUBSCRIPTION_ID \
    --admin

## Check connection
kubectl get pods -A 