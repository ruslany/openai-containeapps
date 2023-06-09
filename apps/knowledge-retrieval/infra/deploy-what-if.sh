az deployment sub what-if \
    --location eastus \
    --template-file main.bicep \
    --parameters @main.parameters.json