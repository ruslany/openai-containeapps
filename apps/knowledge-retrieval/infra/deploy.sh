az deployment sub create \
    --location westus \
    --template-file main.bicep \
    --parameters @main.parameters.json