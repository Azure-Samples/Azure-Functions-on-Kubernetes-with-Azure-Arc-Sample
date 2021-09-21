set -ux

# make sure environment variables loaded from environment-variables.sh - `source environment-variables.sh`
[[ $RESOURCE_GROUP == '' ]] && { echo "initiate environment variables, press any key to exit script">&2; read -n1 -s -r key; exit 1;}

# check working directory is env.
[[ $PWD != *env ]] && { echo 'wrong directory, press any key to exit script'>&2; read -n1 -s -r key; exit 1; }

#create aks
az group create -n $RESOURCE_GROUP -l $LOCATION
az monitor log-analytics workspace create -g $RESOURCE_GROUP -n $LA_WORKSPACE_NAME
LA_WORKSPACE_ID=$(az monitor log-analytics workspace show -g $RESOURCE_GROUP -n $LA_WORKSPACE_NAME --query id -o tsv)
az aks create -g $RESOURCE_GROUP -n $KUBE_CLUSTER --enable-aad --generate-ssh-keys --enable-addons monitoring --workspace-resource-id $LA_WORKSPACE_ID
INFRA_RESOURCE_GROUP=$(az aks show -g $RESOURCE_GROUP -n $KUBE_CLUSTER -o tsv --query nodeResourceGroup)
az network public-ip create -g $INFRA_RESOURCE_GROUP -n $AKS_IP_NAME --sku STANDARD
AKS_IP_VALUE=$(az network public-ip show -g $INFRA_RESOURCE_GROUP -n $AKS_IP_NAME -o tsv --query ipAddress)

az aks get-credentials -g $RESOURCE_GROUP -n $KUBE_CLUSTER --admin

#connect cluster to arc
az connectedk8s connect -g $RESOURCE_GROUP -n $CLUSTER_NAME

#get connected clusterid
CONNECTED_CLUSTER_ID=$(az connectedk8s show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query id -o tsv)
