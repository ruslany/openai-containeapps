az deployment sub create \
    --name 'openai-capps-'$(date +"%d-%b-%Y") \
    --location westus \
    --template-file main.bicep \
    --parameters @main.parameters.json