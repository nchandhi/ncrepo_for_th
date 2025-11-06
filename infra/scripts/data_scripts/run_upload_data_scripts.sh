#!/bin/bash
echo "Starting the data upload script"

# Variables
fabricWorkspaceId="$1"
solutionName="$2"
aiFoundryName="$3"
backend_app_pid="$4"
backend_app_uid="$5"
app_service="$6"
resource_group="$7"
ai_search_endpoint="$8"
azure_openai_endpoint="$9"
embedding_model_name="${10}"
aiFoundryResourceId="${11}"
aiSearchResourceId="${12}"
cosmosdb_account="${13}"



# get parameters from azd env, if not provided
if [ -z "$solutionName" ]; then
    solutionName=$(azd env get-value SOLUTION_NAME)
fi

if [ -z "$aiFoundryName" ]; then
    aiFoundryName=$(azd env get-value AI_SERVICE_NAME)
fi

if [ -z "$backend_app_pid" ]; then
    backend_app_pid=$(azd env get-value API_PID)
fi

if [ -z "$backend_app_uid" ]; then
    backend_app_uid=$(azd env get-value API_UID)
fi

if [ -z "$app_service" ]; then
    app_service=$(azd env get-value API_APP_NAME)
fi

if [ -z "$resource_group" ]; then
    resource_group=$(azd env get-value RESOURCE_GROUP_NAME)
fi

if [ -z "$ai_search_endpoint" ]; then
    ai_search_endpoint=$(azd env get-value AZURE_AI_SEARCH_ENDPOINT)
fi
if [ -z "$azure_openai_endpoint" ]; then
    azure_openai_endpoint=$(azd env get-value AZURE_OPENAI_ENDPOINT)
fi

if [ -z "$embedding_model_name" ]; then
    embedding_model_name=$(azd env get-value AZURE_OPENAI_EMBEDDING_MODEL)
fi

if [ -z "$aiFoundryResourceId" ]; then
    aiFoundryResourceId=$(azd env get-value AI_FOUNDRY_RESOURCE_ID)
fi

if [ -z "$aiSearchResourceId" ]; then
    aiSearchResourceId=$(azd env get-value AI_SEARCH_SERVICE_RESOURCE_ID)
fi

if [ -z "$cosmosdb_account" ]; then
    cosmosdb_account=$(azd env get-value AZURE_COSMOSDB_ACCOUNT)
fi

# cosmosdb_endpoint="https://${cosmosdb_account}.documents.azure.com:443/"

# Check if user is logged in to Azure
echo "Checking Azure authentication..."
if az account show &> /dev/null; then
    echo "Already authenticated with Azure."
else
    # Use Azure CLI login if running locally
    echo "Authenticating with Azure CLI..."
    az login
fi

echo "Getting signed in user id"
signed_user_id=$(az ad signed-in-user show --query id -o tsv)

echo "Checking if the user has Search roles on the AI Search Service"
# search service contributor role id: 7ca78c08-252a-4471-8644-bb5ff32d4ba0
# search index data contributor role id: 8ebe5a00-799e-43f5-93ac-243d3dce84a7
# search index data reader role id: 1407120a-92aa-4202-b7e9-c0e197c71c8f

role_assignment=$(MSYS_NO_PATHCONV=1 az role assignment list \
  --role "7ca78c08-252a-4471-8644-bb5ff32d4ba0" \
  --scope "$aiSearchResourceId" \
  --assignee "$signed_user_id" \
  --query "[].roleDefinitionId" -o tsv)

if [ -z "$role_assignment" ]; then
    echo "User does not have the search service contributor role. Assigning the role..."
    MSYS_NO_PATHCONV=1 az role assignment create \
      --assignee "$signed_user_id" \
      --role "7ca78c08-252a-4471-8644-bb5ff32d4ba0" \
      --scope "$aiSearchResourceId" \
      --output none

    if [ $? -eq 0 ]; then
        echo "Search service contributor role assigned successfully."
    else
        echo "Failed to assign search service contributor role."
        exit 1
    fi
else
    echo "User already has the search service contributor role."
fi

role_assignment=$(MSYS_NO_PATHCONV=1 az role assignment list \
  --role "8ebe5a00-799e-43f5-93ac-243d3dce84a7" \
  --scope "$aiSearchResourceId" \
  --assignee "$signed_user_id" \
  --query "[].roleDefinitionId" -o tsv)

if [ -z "$role_assignment" ]; then
    echo "User does not have the search index data contributor role. Assigning the role..."
    MSYS_NO_PATHCONV=1 az role assignment create \
      --assignee "$signed_user_id" \
      --role "8ebe5a00-799e-43f5-93ac-243d3dce84a7" \
      --scope "$aiSearchResourceId" \
      --output none

    if [ $? -eq 0 ]; then
        echo "Search index data contributor role assigned successfully."
    else
        echo "Failed to assign search index data contributor role."
        exit 1
    fi
else
    echo "User already has the search index data contributor role."
fi

role_assignment=$(MSYS_NO_PATHCONV=1 az role assignment list \
  --role "1407120a-92aa-4202-b7e9-c0e197c71c8f" \
  --scope "$aiSearchResourceId" \
  --assignee "$signed_user_id" \
  --query "[].roleDefinitionId" -o tsv)

if [ -z "$role_assignment" ]; then
    echo "User does not have the search index data reader role. Assigning the role..."
    MSYS_NO_PATHCONV=1 az role assignment create \
      --assignee "$signed_user_id" \
      --role "1407120a-92aa-4202-b7e9-c0e197c71c8f" \
      --scope "$aiSearchResourceId" \
      --output none

    if [ $? -eq 0 ]; then
        echo "Search index data reader role assigned successfully."
    else
        echo "Failed to assign search index data reader role."
        exit 1
    fi
else
    echo "User already has the search index data reader role."
fi


# python -m venv .venv

# .venv\Scripts\activate

requirementFile="infra/scripts/data_scripts/requirements.txt"

# Download and install Python requirements
python -m pip install --upgrade pip
python -m pip install --quiet -r "$requirementFile"



# python pip install -r infra/scripts/data_scripts/requirements.txt --quiet
python infra/scripts/data_scripts/01_create_products_search_index.py --ai_search_endpoint="$ai_search_endpoint" --azure_openai_endpoint="$azure_openai_endpoint" --embedding_model_name="$embedding_model_name"
python infra/scripts/data_scripts/02_create_policies_search_index.py --ai_search_endpoint="$ai_search_endpoint" --azure_openai_endpoint="$azure_openai_endpoint" --embedding_model_name="$embedding_model_name"
python infra/scripts/data_scripts/03_write_products_to_cosmos.py --cosmosdb_account="$cosmosdb_account"
# python infra/scripts/data_scripts/02_create_policies_search_index.py
# python infra/scripts/data_scripts/03_write_products_to_cosmos.py

# # Variables
# fabricWorkspaceId="$1"
# solutionName="$2"
# aiFoundryName="$3"
# backend_app_pid="$4"
# backend_app_uid="$5"
# app_service="$6"
# resource_group="$7"

# # get parameters from azd env, if not provided
# if [ -z "$solutionName" ]; then
#     solutionName=$(azd env get-value SOLUTION_NAME)
# fi

# if [ -z "$aiFoundryName" ]; then
#     aiFoundryName=$(azd env get-value AI_SERVICE_NAME)
# fi

# if [ -z "$backend_app_pid" ]; then
#     backend_app_pid=$(azd env get-value API_PID)
# fi

# if [ -z "$backend_app_uid" ]; then
#     backend_app_uid=$(azd env get-value API_UID)
# fi

# if [ -z "$app_service" ]; then
#     app_service=$(azd env get-value API_APP_NAME)
# fi

# if [ -z "$resource_group" ]; then
#     resource_group=$(azd env get-value RESOURCE_GROUP_NAME)
# fi


# # Check if all required arguments are present
# if [ -z "$fabricWorkspaceId" ] || [ -z "$solutionName" ] || [ -z "$aiFoundryName" ] || [ -z "$backend_app_pid" ] || [ -z "$backend_app_uid" ] || [ -z "$app_service" ] || [ -z "$resource_group" ]; then
#     echo "Usage: $0 <fabricWorkspaceId> <solutionName> <aiFoundryName> <backend_app_pid> <backend_app_uid> <app_service> <resource_group>"
#     exit 1
# fi

# # Check if user is logged in to Azure
# echo "Checking Azure authentication..."
# if az account show &> /dev/null; then
#     echo "Already authenticated with Azure."
# else
#     # Use Azure CLI login if running locally
#     echo "Authenticating with Azure CLI..."
#     az login
# fi

# # # get signed user
# # echo "Getting signed in user id"
# # signed_user_id=$(az ad signed-in-user show --query id -o tsv)

# # # Check if the user_id is empty
# # if [ -z "$signed_user_id" ]; then
# #     echo "Error: User ID not found. Please check the user principal name or email address."
# #     exit 1
# # fi

# # # # Define the scope for the Key Vault (replace with your Key Vault resource ID)
# # # echo "Getting key vault resource id"
# # # key_vault_resource_id=$(az keyvault show --name $keyvaultName --query id --output tsv)

# # # # Check if the key_vault_resource_id is empty
# # # if [ -z "$key_vault_resource_id" ]; then
# # #     echo "Error: Key Vault not found. Please check the Key Vault name."
# # #     exit 1
# # # fi

# # # # Assign the Key Vault Administrator role to the user
# # # echo "Assigning the Key Vault Administrator role to the user..."
# # # az role assignment create --assignee $signed_user_id --role "Key Vault Administrator" --scope $key_vault_resource_id

# # # Define the scope for the Azure AI Foundry resource
# # echo "Getting Azure AI Foundry id"
# # # aiFoundryId=$(az resource show --name $aiFoundryName --resource-type "Microsoft.AI" --resource-group $resource_group --query id --output tsv)

# # az account set --subscription ""

# # ai_foundry_resource_id=$(az cognitiveservices account show \
# #   --name "$aiFoundryName" --resource-group "$resource_group" \
# #   --query id -o tsv)

# # echo "Azure AI Foundry ID: $ai_foundry_resource_id"

# # echo "Assigning the Azure AI User role to the user..."
# # az role assignment create --assignee $signed_user_id --role "53ca6127-db72-4b80-b1b0-d745d6d5456d" --scope $ai_foundry_resource_id

# # # Check if the role assignment command was successful
# # if [ $? -ne 0 ]; then
# #     echo "Error: Role assignment failed. Please check the provided details and your Azure permissions."
# #     exit 1
# # fi
# # echo "Role assignment completed successfully."

# #Replace key vault name and workspace id in the python files
# # sed -i "s/kv_to-be-replaced/${keyvaultName}/g" "create_fabric_items.py"
# # sed -i "s/solutionName_to-be-replaced/${solutionName}/g" "create_fabric_items.py"
# # sed -i "s/workspaceId_to-be-replaced/${fabricWorkspaceId}/g" "create_fabric_items.py"
# python -m pip install -r infra/scripts/fabric_scripts/requirements.txt --quiet

# # Run Python unbuffered so prints show immediately.
# tmp="$(mktemp)"
# cleanup() { rm -f "$tmp"; }
# trap cleanup EXIT

# python -u infra/scripts/fabric_scripts/create_fabric_items.py --workspaceId "$fabricWorkspaceId" --solutionname "$solutionName" --backend_app_pid "$backend_app_pid" --backend_app_uid "$backend_app_uid" --exports-file "$tmp"

# source "$tmp"

# FABRIC_SQL_SERVER="$FABRIC_SQL_SERVER1"
# FABRIC_SQL_DATABASE="$FABRIC_SQL_DATABASE1"
# FABRIC_SQL_CONNECTION_STRING="$FABRIC_SQL_CONNECTION_STRING1"

# # Update environment variables of API App
# az webapp config appsettings set \
#   --resource-group "$resource_group" \
#   --name "$app_service" \
#   --settings FABRIC_SQL_SERVER="$FABRIC_SQL_SERVER" FABRIC_SQL_DATABASE="$FABRIC_SQL_DATABASE" FABRIC_SQL_CONNECTION_STRING="$FABRIC_SQL_CONNECTION_STRING" \
#   -o none

# echo "Environment variables updated for App Service: $app_service"
