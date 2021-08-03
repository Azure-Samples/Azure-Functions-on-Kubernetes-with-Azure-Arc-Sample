set -ux 

# check working directory is env.
[[ $PWD != *env ]] && { echo 'wrong directory, press any key to exit script'>&2; read -n1 -s -r key; exit 1; }

#create role assignment to allow azure websites to manage the cluster
MICROSOFT_AZURE_WEBSITES_OID=$(az ad sp show --id 'abfa0a7c-a6b6-4736-8310-5855508787cd' --query objectId -o tsv)
CUSTOM_LOCATION_OID=$(az ad sp show --id 'bc313c14-388c-4e7d-a58e-70017303ee3b' --query objectId -o tsv)
az role assignment create --assignee-object-id $MICROSOFT_AZURE_WEBSITES_OID --role Owner --scope "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}"

#create app service extension
az k8s-extension create -g $RESOURCE_GROUP --name $EXTENSION_NAME \
    --cluster-type connectedClusters \
    -c $CLUSTER_NAME \
    --extension-type 'Microsoft.Web.Appservice' \
    --release-train stable \
    --auto-upgrade-minor-version true \
    --scope cluster \
    --release-namespace "$CUSTOM_LOCATION_NAMESPACE" \
    --configuration-settings "Microsoft.CustomLocation.ServiceAccount=default" \
    --configuration-settings "appsNamespace=$CUSTOM_LOCATION_NAMESPACE" \
    --configuration-settings "clusterName=${KUBE_ENVIRONMENT}" \
    --configuration-settings "loadBalancerIp=${AKS_IP_VALUE}" \
    --configuration-settings "buildService.storageClassName=default" \
    --configuration-settings "buildService.storageAccessMode=ReadWriteOnce" \
    --configuration-settings "customConfigMap=$CUSTOM_LOCATION_NAMESPACE/kube-environment-config" \
    --configuration-settings "envoy.annotations.service.beta.kubernetes.io/azure-load-balancer-resource-group=${RESOURCE_GROUP}"

EXTENSION_ID=$(az k8s-extension show --cluster-type connectedClusters -c $CLUSTER_NAME -g $RESOURCE_GROUP --name $EXTENSION_NAME --query id -o tsv)
az resource wait --ids $EXTENSION_ID --custom "properties.installState=='Installed' || properties.installState=='Failed'"  --api-version "2020-07-01-preview"

EXTENSION_INSTALL_STATE=$(az k8s-extension show --cluster-type connectedClusters -c $CLUSTER_NAME -g $RESOURCE_GROUP --name $EXTENSION_NAME --query "installState" -o tsv) && echo $EXTENSION_INSTALL_STATE
[[ $EXTENSION_INSTALL_STATE != "Installed" ]] && echo "extension not installed, check for errors">&2

#create customLocation
az customlocation create -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME --host-resource-id $CONNECTED_CLUSTER_ID --namespace $CUSTOM_LOCATION_NAMESPACE -c $EXTENSION_ID
CUSTOM_LOCATION_ID=$(az customlocation show -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME --query id -o tsv)

# create app service kube environment
az appservice kube create -g $RESOURCE_GROUP -n $KUBE_ENVIRONMENT --location $APP_SERVICE_PLAN_LOCATION --custom-location $CUSTOM_LOCATION_ID --static-ip "$AKS_IP_VALUE" 

KUBE_ENV_INSTALL_STATE=$(az appservice kube show -g $RESOURCE_GROUP -n $KUBE_ENVIRONMENT --query provisioningState -o tsv --query provisioningState)
[[ $KUBE_ENV_INSTALL_STATE != "Succeeded" ]] && echo "kube environment not provisioned, check for errors">&2
