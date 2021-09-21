set -ux 

# make sure environment variables loaded from environment-variables.sh - `source environment-variables.sh`
[[ $RESOURCE_GROUP == '' ]] && echo "RESOURCE_GROUP not set, initiate environment variables">&2

pushd .
cd ../src/ReviewsValidator

# check working directory is src/ReviewsValidator.
[[ $PWD != *src/ReviewsValidator ]] && { echo 'wrong directory, press any key to exit script'>&2; read -n1 -s -r key; exit 1; }

az storage account create --name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --location $LOCATION --sku Standard_LRS
STORAGE_CONNECTION_STRING=$(az storage account show-connection-string -n $STORAGE_ACCOUNT -g $RESOURCE_GROUP --query 'connectionString' -o tsv)

az monitor app-insights component create -a $APPINSIGHTS_NAME -l $LOCATION -g $RESOURCE_GROUP --workspace $LA_WORKSPACE_NAME

az functionapp create -g $RESOURCE_GROUP -n $APP_NAME --custom-location $CUSTOM_LOCATION_ID -s $STORAGE_ACCOUNT --functions-version 3 --runtime 'dotnet' --app-insights $APPINSIGHTS_NAME

az functionapp config appsettings set -g $RESOURCE_GROUP -n $APP_NAME --settings "ReviewsStorage=$STORAGE_CONNECTION_STRING"

PUBLISH_FILE_PATH=../publish.zip

dotnet publish -o ./Publish
cd ./Publish
zip -r $PUBLISH_FILE_PATH .

az functionapp deployment source config-zip --src $PUBLISH_FILE_PATH -g $RESOURCE_GROUP -n $APP_NAME

FUNCTION_HOST=$(az functionapp show  -g $RESOURCE_GROUP -n $APP_NAME --query "hostNames[0]" -o tsv)

# Give function app a moment to finish restart
sleep 15
HEALTHCHECK_HTTP_RESULT=$(curl https://$FUNCTION_HOST/api/ReviewsValidatorHealth -s -o /dev/null -w "%{http_code}")
[[ $HEALTHCHECK_HTTP_RESULT != 200 ]] && echo "healthcheck failed"

EVENTGRID_SYSTEM_KEY=$(az functionapp keys list  -g $RESOURCE_GROUP -n $APP_NAME --query "systemKeys.eventgrid_extension" -o tsv)
EVENTGRID_TRIGGER_URL="https://${FUNCTION_HOST}/runtime/webhooks/eventgrid?functionName=ReviewsValidator&code=$EVENTGRID_SYSTEM_KEY"

echo "event grid url: $EVENTGRID_TRIGGER_URL"
echo "http trigger url: https://$FUNCTION_HOST/api/ReviewsValidatorHealth"

popd