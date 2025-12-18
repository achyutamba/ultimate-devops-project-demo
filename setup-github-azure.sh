#!/bin/bash
set -e

echo "=== Setting up Azure Service Principal for GitHub Actions ==="

# Variables
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
GITHUB_ORG="achyutamba"
GITHUB_REPO="ultimate-devops-project-demo"
SP_NAME="github-actions-otel-demo"

echo "Subscription: $SUBSCRIPTION_ID"
echo "Creating service principal..."

# Create service principal
SP_OUTPUT=$(az ad sp create-for-rbac \
  --name "$SP_NAME" \
  --role contributor \
  --scopes /subscriptions/$SUBSCRIPTION_ID \
  --json-auth)

CLIENT_ID=$(echo $SP_OUTPUT | jq -r .clientId)

echo "Service Principal created!"
echo "Client ID: $CLIENT_ID"

# Configure OIDC federation
echo "Configuring OIDC federation..."
az ad app federated-credential create \
  --id $CLIENT_ID \
  --parameters "{
    \"name\": \"github-actions-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$GITHUB_ORG/$GITHUB_REPO:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"

echo ""
echo "=== ✅ SETUP COMPLETE ==="
echo ""
echo "Add these secrets to GitHub:"
echo "https://github.com/$GITHUB_ORG/$GITHUB_REPO/settings/secrets/actions"
echo ""
echo "AZURE_CLIENT_ID=$CLIENT_ID"
echo "AZURE_TENANT_ID=$TENANT_ID"
echo "AZURE_SUBSCRIPTION_ID=$SUBSCRIPTION_ID"
echo ""
