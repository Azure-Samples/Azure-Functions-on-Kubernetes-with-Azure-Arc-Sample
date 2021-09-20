set -ux 

# check working directory is env.
[[ $PWD != *env ]] && { echo 'wrong directory'>&2; }

# add current user to admins
CURRENT_USER_OID=$(az ad signed-in-user show --query "objectId" -o tsv)
kubectl create clusterrolebinding admin-binding --clusterrole=cluster-admin --user=$CURRENT_USER_OID

mkdir certs
cd certs

#create server PKI certs for eventgrid intercomponent auth, specify a Common Name when prompted - using a different one for CA and Certs
openssl rand -hex 16 > pass
openssl req -newkey rsa:4096 -keyform PEM -keyout ca.key -x509 -days 3650 -passout file:pass -outform PEM -subj "/CN=sample-evtgrid-ca" -out ca.cer
openssl genrsa -out server.key 4096
openssl req -new -key server.key -out server.req -sha256 -subj "/CN=sample-evtgrid-server" 
openssl x509 -req -in server.req -CA ca.cer -CAkey ca.key -set_serial 100 -passin file:pass -extensions server -days 1460 -outform PEM -out server.cer -sha256

# verify that the server certificate was created ok
openssl verify -CAfile ca.cer server.cer
rm server.req

#create client PKI certs certs for eventgrid intercomponent auth, specify a Common Name when prompted - using a different one for CA and Certs
openssl genrsa -out client.key 4096
openssl req -new -key client.key -out client.req  -subj "/CN=sample-evtgrid-client" 
openssl x509 -req -in client.req -CA ca.cer -CAkey ca.key -set_serial 101 -passin file:pass -extensions client -days 365 -outform PEM -out client.cer

# verify that the server certificate was created ok
openssl verify -CAfile ca.cer client.cer

rm client.req

#create settings files for extension

echo "{ 
    \"eventgridoperator.identityCert.base64EncodedIdentityCert\":\"$(base64 client.cer --wrap=0)\",
    \"eventgridoperator.identityCert.base64EncodedIdentityKey\":\"$(base64 client.key --wrap=0)\",
    \"eventgridoperator.identityCert.base64EncodedIdentityCaCert\":\"$(base64 ca.cer --wrap=0)\",
    \"eventgridbroker.service.tls.base64EncodedServerCert\":  \"$(base64 server.cer --wrap=0)\" ,
    \"eventgridbroker.service.tls.base64EncodedServerKey\":  \"$(base64 server.key --wrap=0)\" ,
    \"eventgridbroker.service.tls.base64EncodedServerCaCert\":  \"$(base64 ca.cer --wrap=0)\" 
}" > protected-settings-extension.json 

echo "{
    \"Microsoft.CustomLocation.ServiceAccount\":\"eventgrid-operator\",
    \"eventgridbroker.service.serviceType\": \"LoadBalancer\",
    \"eventgridbroker.dataStorage.storageClassName\": \"azurefile\",
    \"eventgridbroker.diagnostics.metrics.reporterType\":\"prometheus\"
}" > settings-extension.json

# install extension
az k8s-extension create \
    --cluster-type connectedClusters \
    --cluster-name $CLUSTER_NAME \
    --resource-group $RESOURCE_GROUP \
    --name $EVENT_GRID_EXTENSION_NAME \
    --extension-type Microsoft.EventGrid \
    --scope cluster \
    --auto-upgrade-minor-version true \
    --release-train Stable \
    --release-namespace eventgrid-ext \
    --configuration-protected-settings-file protected-settings-extension.json \
    --configuration-settings-file settings-extension.json

EVENTGRID_EXTENSION_ID=$(az k8s-extension show --cluster-type connectedClusters -c $CLUSTER_NAME -g $RESOURCE_GROUP --name $EVENT_GRID_EXTENSION_NAME --query id -o tsv)
az resource wait --ids $EVENTGRID_EXTENSION_ID --custom "properties.installState=='Installed' || properties.installState=='Failed'" --api-version "2020-07-01-preview"

# check install state, don't proceed until installed.
EVENTGRID_EXTENSION_INSTALLSTATE=$(az k8s-extension show --cluster-type connectedClusters --cluster-name $CLUSTER_NAME --resource-group $RESOURCE_GROUP --name $RESOURCE_GROUP-eventgrid-extension --query installState -o tsv) && echo $EVENTGRID_EXTENSION_INSTALLSTATE
[[ $EVENTGRID_EXTENSION_INSTALLSTATE != "Installed" ]] && echo "not installed, check for errors">&2

cd ..

az customlocation create -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME_EVENTGRID -l $LOCATION --host-resource-id $CONNECTED_CLUSTER_ID --namespace $CUSTOM_LOCATION_NAMESPACE_EVENTGRID -c $EVENTGRID_EXTENSION_ID
CUSTOM_LOCATION_ID_EVENTGRID=$(az customlocation show -g $RESOURCE_GROUP -n $CUSTOM_LOCATION_NAME_EVENTGRID --query id -o tsv)

# create topic
az eventgrid topic create -g $RESOURCE_GROUP -n $EVENT_GRID_TOPIC_NAME --kind azurearc -l $LOCATION  --extended-location-name $CUSTOM_LOCATION_ID_EVENTGRID --extended-location-type CustomLocation --input-schema cloudeventschemav1_0
EVENT_GRID_TOPIC_ID=$(az eventgrid topic show -g $RESOURCE_GROUP -n $EVENT_GRID_TOPIC_NAME --query id -o tsv)

# This variable should be set by deploy.sh when deploying the function app. 
# Use the below options to set it for testing the subscription with eventgrid or http triggered endpoints in other locations.
# EVENTGRID_TRIGGER_URL="https://${FUNCTION_HOST}/runtime/webhooks/eventgrid?functionName=ReviewsValidator"
# EVENTGRID_TRIGGER_URL="https://${FUNCTION_HOST}/api/ReviewsValidatorHealth"

# create subscription
az eventgrid event-subscription create -n $EVENT_GRID_SUBSCRIPTION_NAME --source-resource-id $EVENT_GRID_TOPIC_ID --endpoint  $EVENTGRID_TRIGGER_URL

# test the topic by posting an event to it.
TOPIC_ACCESS_KEY=$(az rest --method post -u "/subscriptions/${SUBSCRIPTION_ID}/resourcegroups/${RESOURCE_GROUP}/providers/Microsoft.EventGrid/topics/${EVENT_GRID_TOPIC_NAME}/listKeys?api-version=2020-10-15-preview" --query "key1" -o tsv)

# nginx
kubectl create namespace eventgrid-ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
    --namespace eventgrid-ingress \
    --set controller.replicaCount=2 \
    --set controller.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set defaultBackend.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set controller.admissionWebhooks.patch.nodeSelector."beta\.kubernetes\.io/os"=linux \
    --set "controller.extraArgs.enable-ssl-passthrough=true"

kubectl apply -f ingress-route.yaml

# retry in case of intermittent error
[[ $? -gt 0 ]] && { kubectl apply -f ingress-route.yaml; }

TOPIC_IP=$(kubectl get service nginx-ingress-ingress-nginx-controller --namespace eventgrid-ingress   -o jsonpath="{.status.loadBalancer.ingress[0].ip}"):443

set +ux
