# get a string which is a current date and time
now=$(date +"%d-%b-%Y-%H-%M-%S")

name='openai-capps'
deploymentName=$name'-'$now
location='eastus'

principalId=$(az ad signed-in-user show --query id -o tsv)

# Check if an argument equals a string 'what-if'
if [ "$1" = "what-if" ]; then
    az deployment sub what-if \
        --name $deploymentName \
        --location $location \
        --template-file main.bicep \
        --parameters name=$name location=$location principalId=$principalId \
        --debug
    exit 0
fi

az deployment sub create \
    --name $deploymentName \
    --location $location \
    --template-file main.bicep \
    --parameters name=$name location=$location principalId=$principalId \
