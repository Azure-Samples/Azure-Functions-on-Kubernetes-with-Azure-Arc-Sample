# update the resource group name: all other resource names are generated from this.
export RESOURCE_GROUP="{enter resource-group-name here}"
export LOCATION="eastus"
export APP_SERVICE_PLAN_LOCATION="eastus"
export STORAGE_ACCOUNT=$(echo $RESOURCE_GROUP | tr -dc '[:alnum:]\n\r' | tr '[:upper:]' '[:lower:]')
export STORAGE_NAME_VALID=$(az storage account check-name -n $STORAGE_ACCOUNT --query "nameAvailable" -o tsv)
[[ $STORAGE_NAME_VALID == false ]] && echo "Storage name is not valid">&2

export APP_NAME="${RESOURCE_GROUP}-functions"
export APP_SERVICE_PLAN="${RESOURCE_GROUP}-appserviceplan"
export KUBE_CLUSTER="${RESOURCE_GROUP}-aks"
export AKS_IP_NAME="${RESOURCE_GROUP}-ip"

# The client app ID for your AAD-enabled cluster. If using the AKS-enabled AAD, the value is "80faf920-1908-4b52-b5ef-a8e7bedfc67a"
export CLIENT_APP_ID="80faf920-1908-4b52-b5ef-a8e7bedfc67a"
# The server app ID for your AAD-enabled cluster. If using the AKS-enabled AAD, the value is "6dae42f8-4368-4678-94ff-3960e28e3630"
export SERVER_APP_ID="6dae42f8-4368-4678-94ff-3960e28e3630"
# The subscription ID into which your resources will be provisioned
export SUBSCRIPTION_ID=$(az account show --query id -o tsv)
# The desired name of your connected cluster resource    
export CLUSTER_NAME="${RESOURCE_GROUP}-cluster" 
# The desired name of the extension to be installed in the connected cluster
export EXTENSION_NAME="${RESOURCE_GROUP}-appsvc-extension" 
# The desired name of your custom location    
export CUSTOM_LOCATION_NAME="${RESOURCE_GROUP}-location"
export CUSTOM_LOCATION_NAMESPACE="arc-enabled-functions-sample"
export CUSTOM_LOCATION_NAME_EVENTGRID="${RESOURCE_GROUP}-location-eventgrid"
export CUSTOM_LOCATION_NAMESPACE_EVENTGRID="arc-enabled-functions-sample-eventgrid"

# The desired name of your Kubernetes environment -THIS MUST CURRENTLY MATCH THE KUBE EXTENSION NAME
export KUBE_ENVIRONMENT=$EXTENSION_NAME

export EVENT_GRID_EXTENSION_NAME="${RESOURCE_GROUP}-eventgrid-extension"


export EVENT_GRID_TOPIC_NAME="${RESOURCE_GROUP}-eventgrid-topic"
export EVENT_GRID_SUBSCRIPTION_NAME="${RESOURCE_GROUP}-eventgrid-subscription"

export APPINSIGHTS_NAME="${RESOURCE_GROUP}-appinsights"