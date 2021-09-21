set -ux 

source environment-variables.12.sh

INFRA_RESOURCE_GROUP=$(az aks show -g $RESOURCE_GROUP -n $KUBE_CLUSTER -o tsv --query nodeResourceGroup)
LA_WORKSPACE_ID=$(az monitor log-analytics workspace show -g $RESOURCE_GROUP -n $LA_WORKSPACE_NAME --query id -o tsv)
AKS_IP_VALUE=$(az network public-ip show -g $INFRA_RESOURCE_GROUP -n $AKS_IP_NAME -o tsv --query ipAddress)
CONNECTED_CLUSTER_ID=$(az connectedk8s show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query id -o tsv)

az aks get-credentials -g $RESOURCE_GROUP -n $KUBE_CLUSTER --admin

EXTENSION_ID=$(az k8s-extension show --cluster-type connectedClusters -c $CLUSTER_NAME -g $RESOURCE_GROUP --name $EXTENSION_NAME --query id -o tsv)
CUSTOM_LOCATION_ID=$(az customlocation show -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME --query id -o tsv)


STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP --query 'connectionString' -o tsv)
APPINSIGHTS_INSTRUMENTATION_KEY=$(az monitor app-insights component show -a $APPINSIGHTS_NAME -g $RESOURCE_GROUP --query "instrumentationKey" -o tsv)

FUNCTION_HOST=$(az functionapp show  -g $RESOURCE_GROUP -n $APP_NAME --query "hostNames[0]" -o tsv)
EVENTGRID_SYSTEM_KEY=$(az functionapp keys list  -g $RESOURCE_GROUP -n $APP_NAME --query "systemKeys.eventgrid_extension" -o tsv)
EVENTGRID_TRIGGER_URL="https://${FUNCTION_HOST}/runtime/webhooks/eventgrid?functionName=ReviewsValidator&code=$EVENTGRID_SYSTEM_KEY"

CUSTOM_LOCATION_ID_EVENTGRID=$(az customlocation show -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME_EVENTGRID --query id -o tsv)
EVENT_GRID_TOPIC_ID=$(az eventgrid topic show -g $RESOURCE_GROUP -n $EVENT_GRID_TOPIC_NAME --query id -o tsv)

TOPIC_ACCESS_KEY=$(az rest --method post -u "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP}/providers/Microsoft.EventGrid/topics/${EVENT_GRID_TOPIC_NAME}/listKeys?api-version=2020-10-15-preview" --query "key1" -o tsv)
TOPIC_IP=$(kubectl get service nginx-ingress-ingress-nginx-controller --namespace eventgrid-ingress -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):443

set +ux 
