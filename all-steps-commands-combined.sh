# Step 01 - Prerequisites - Run the following command only once
az feature register --namespace "Microsoft.ContainerService" -n "EnableWorkloadIdentityPreview"
az feature register --namespace "Microsoft.ContainerService" -n "EnableImageCleanerPreview"

# Keep running until all say "Registered." (This may take up to 20 minutes.)
az feature list -o table --query "[?name=='Microsoft.ContainerService/EnableWorkloadIdentityPreview' || name=='Microsoft.ContainerService/EnableImageCleanerPreview'].{Name:name,State:properties.state}"

# When all say "Registered" then re-register the AKS resource provider
az provider register --namespace Microsoft.ContainerService

# It is not needed to clone the repository as this repo has all the required files
# git clone https://github.com/mspnp/aks-baseline.git
# cd aks-baseline

# Step 02 - Generate your client-facing and AKS ingress controller TLS certificates

export DOMAIN_NAME_AKS_BASELINE="domain-name.com"

# run either option 1 or 2, but must run at least one of the options to create the PFX/CRT files for Application Gateway

# Option 1
# if you wish to create a self-signed certificat, use the following two commands to create a PFX and CRT files
# openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out appgw.crt -keyout appgw.key -subj "/CN=bicycle.${DOMAIN_NAME_AKS_BASELINE}/O=Contoso Bicycle" -addext "subjectAltName = DNS:bicycle.${DOMAIN_NAME_AKS_BASELINE}" -addext "keyUsage = digitalSignature" -addext "extendedKeyUsage = serverAuth"
# openssl pkcs12 -export -out appgw.pfx -in appgw.crt -inkey appgw.key -passout pass:

# Option 2
# if you wish to bring in your certificate PFX file, then use the following line to create the public CRT certificate file
# openssl pkcs12 -in appgw.pfx -clcerts -nokeys -out appgw.crt

export APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE=$(cat appgw.pfx | base64 | tr -d '\n')
echo APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE: $APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE

openssl req -x509 -nodes -days 365 -newkey rsa:2048 -out traefik-ingress-internal-aks-ingress-tls.crt -keyout traefik-ingress-internal-aks-ingress-tls.key -subj "/CN=*.aks-ingress.${DOMAIN_NAME_AKS_BASELINE}/O=Contoso AKS Ingress"

export AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE=$(cat traefik-ingress-internal-aks-ingress-tls.crt | base64 | tr -d '\n')
echo AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE: $AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE

# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env

# Step 03 - Prep for Azure Active Directory integration

export TENANTID_AZURERBAC_AKS_BASELINE=$(az account show --query tenantId -o tsv)
echo TENANTID_AZURERBAC_AKS_BASELINE: $TENANTID_AZURERBAC_AKS_BASELINE

az login -t $TENANTID_AZURERBAC_AKS_BASELINE --allow-no-subscriptions
export TENANTID_K8SRBAC_AKS_BASELINE=$(az account show --query tenantId -o tsv)
echo TENANTID_K8SRBAC_AKS_BASELINE: $TENANTID_K8SRBAC_AKS_BASELINE

export AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE=[Paste your existing cluster admin group Object ID here.]
echo AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE: $AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE

export AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE=$(az ad group create --display-name 'cluster-admins-bu0001a000800' --mail-nickname 'cluster-admins-bu0001a000800' --description "Principals in this group are cluster admins in the bu0001a000800 cluster." --query id -o tsv)
echo AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE: $AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE

TENANTDOMAIN_K8SRBAC=$(az ad signed-in-user show --query 'userPrincipalName' -o tsv | cut -d '@' -f 2 | sed 's/\"//')
AADOBJECTNAME_USER_CLUSTERADMIN=bu0001a000800-admin
AADOBJECTID_USER_CLUSTERADMIN=$(az ad user create --display-name=${AADOBJECTNAME_USER_CLUSTERADMIN} --user-principal-name ${AADOBJECTNAME_USER_CLUSTERADMIN}@${TENANTDOMAIN_K8SRBAC} --force-change-password-next-sign-in --password ChangeMebu0001a0008AdminChangeMe --query id -o tsv)
echo TENANTDOMAIN_K8SRBAC: $TENANTDOMAIN_K8SRBAC
echo AADOBJECTNAME_USER_CLUSTERADMIN: $AADOBJECTNAME_USER_CLUSTERADMIN
echo AADOBJECTID_USER_CLUSTERADMIN: $AADOBJECTID_USER_CLUSTERADMIN

export AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE=$(az ad group create --display-name 'cluster-ns-a0008-readers-bu0001a000800' --mail-nickname 'cluster-ns-a0008-readers-bu0001a000800' --description "Principals in this group are readers of namespace a0008 in the bu0001a000800 cluster." --query id -o tsv)
echo AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE: $AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE

# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env

# Stop 04 - Deploy the hub-spoke network topology

# [This takes less than one minute to run.]
az group create -n rg-enterprise-networking-hubs -l centralus

# [This takes less than one minute to run.]
az group create -n rg-enterprise-networking-spokes -l centralus

# [This takes around four minutes to run.]
az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-default.bicep -p location=eastus2

RESOURCEID_VNET_HUB=$(az deployment group show -g rg-enterprise-networking-hubs -n hub-default --query properties.outputs.hubVnetId.value -o tsv)
echo RESOURCEID_VNET_HUB: $RESOURCEID_VNET_HUB

# [This takes about four minutes to run.]
az deployment group create -g rg-enterprise-networking-spokes -f networking/spoke-BU0001A0008.bicep -p location=eastus2 hubVnetResourceId="${RESOURCEID_VNET_HUB}"

RESOURCEID_SUBNET_NODEPOOLS=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.nodepoolSubnetResourceIds.value -o json)
echo RESOURCEID_SUBNET_NODEPOOLS: $RESOURCEID_SUBNET_NODEPOOLS

# [This takes about ten minutes to run.]
az deployment group create -g rg-enterprise-networking-hubs -f networking/hub-regionA.bicep -p location=eastus2 nodepoolSubnetResourceIds="${RESOURCEID_SUBNET_NODEPOOLS}"

# Step 05 - Prep for cluster bootstrapping

# [This takes less than one minute.]
az group create --name rg-bu0001a0008 --location eastus2

export RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE=$(az deployment group show -g rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.clusterVnetResourceId.value -o tsv)
echo RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE: $RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE

# [This takes about four minutes.]
az deployment group create -g rg-bu0001a0008 -f acr-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE} location=eastus2

# Get your ACR instance name
export ACR_NAME_AKS_BASELINE=$(az deployment group show -g rg-bu0001a0008 -n acr-stamp --query properties.outputs.containerRegistryName.value -o tsv)
echo ACR_NAME_AKS_BASELINE: $ACR_NAME_AKS_BASELINE

# Import core image(s) hosted in public container registries to be used during bootstrapping
az acr import --source ghcr.io/kubereboot/kured:1.12.0 -n $ACR_NAME_AKS_BASELINE

# Non-MacOs compatible command
sed -i "s:ghcr.io:${ACR_NAME_AKS_BASELINE}.azurecr.io:" ./cluster-manifests/cluster-baseline-settings/kured.yaml

# On MacOs, run this command instead
sed -i '' 's:ghcr.io:'"${ACR_NAME_AKS_BASELINE}"'.azurecr.io:g' ./cluster-manifests/cluster-baseline-settings/kured.yaml

git commit -a -m "Update image source to use my ACR instance instead of a public container registry."
git push

# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env

# Step 06 - Deploy the AKS cluster

GITOPS_REPOURL=$(git config --get remote.origin.url)
echo GITOPS_REPOURL: $GITOPS_REPOURL

GITOPS_CURRENT_BRANCH_NAME=$(git branch --show-current)
echo GITOPS_CURRENT_BRANCH_NAME: $GITOPS_CURRENT_BRANCH_NAME

# [This takes about 18 minutes.]
az deployment group create -g rg-bu0001a0008 -f cluster-stamp.bicep -p targetVnetResourceId=${RESOURCEID_VNET_CLUSTERSPOKE_AKS_BASELINE} clusterAdminAadGroupObjectId=${AADOBJECTID_GROUP_CLUSTERADMIN_AKS_BASELINE} a0008NamespaceReaderAadGroupObjectId=${AADOBJECTID_GROUP_A0008_READER_AKS_BASELINE} k8sControlPlaneAuthorizationTenantId=${TENANTID_K8SRBAC_AKS_BASELINE} appGatewayListenerCertificate=${APP_GATEWAY_LISTENER_CERTIFICATE_AKS_BASELINE} aksIngressControllerCertificate=${AKS_INGRESS_CONTROLLER_CERTIFICATE_BASE64_AKS_BASELINE} domainName=${DOMAIN_NAME_AKS_BASELINE} gitOpsBootstrappingRepoHttpsUrl=${GITOPS_REPOURL} gitOpsBootstrappingRepoBranch=${GITOPS_CURRENT_BRANCH_NAME} location=eastus2

# Step 07 - Validate your cluster is bootstrapped and enrolled in GitOps

sudo az aks install-cli
kubectl version --client

AKS_CLUSTER_NAME=$(az aks list -g rg-bu0001a0008 --query '[0].name' -o tsv)
echo AKS_CLUSTER_NAME: $AKS_CLUSTER_NAME

az aks get-credentials -g rg-bu0001a0008 -n $AKS_CLUSTER_NAME


# if you get the following error
#
# Error from server (Forbidden): nodes is forbidden: User "user.name@domain.com" cannot list resource "nodes" in API group "" at the cluster scope: User does not have access to the resource in Azure. Update role assignment to allow access.
#
# then grant RBAC "Azure Kubernetes Service RBAC Cluster Admin" role access to the user
# this may take from few seconds to few minutes to take affect

kubectl get nodes

kubectl get namespaces
kubectl get all -n cluster-baseline-settings


kubectl apply -f cluster-manifests/a0008/ # run this twice
kubectl apply -f cluster-manifests/a0008/



# Step 08 - Workload prerequisites

export KEYVAULT_NAME_AKS_BASELINE=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.keyVaultName.value -o tsv)
echo KEYVAULT_NAME_AKS_BASELINE: $KEYVAULT_NAME_AKS_BASELINE
TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT=$(az role assignment create --role a4417e6f-fecd-4de8-b567-7b0420556985 --assignee-principal-type user --assignee-object-id $(az ad signed-in-user show --query 'id' -o tsv) --scope $(az keyvault show --name $KEYVAULT_NAME_AKS_BASELINE --query 'id' -o tsv) --query 'id' -o tsv)
echo TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT: $TEMP_ROLEASSIGNMENT_TO_UPLOAD_CERT

# If you are behind a proxy or some other egress that does not provide a consistent IP, you'll need to manually adjust the
# Azure Key Vault firewall to allow this traffic.
CURRENT_IP_ADDRESS=$(curl -s -4 https://ifconfig.io)
  echo CURRENT_IP_ADDRESS: $CURRENT_IP_ADDRESS
  az keyvault network-rule add -n $KEYVAULT_NAME_AKS_BASELINE --ip-address ${CURRENT_IP_ADDRESS}

cat traefik-ingress-internal-aks-ingress-tls.crt traefik-ingress-internal-aks-ingress-tls.key > traefik-ingress-internal-aks-ingress-tls.pem
az keyvault certificate import -f traefik-ingress-internal-aks-ingress-tls.pem -n traefik-ingress-internal-aks-ingress-tls --vault-name $KEYVAULT_NAME_AKS_BASELINE

kubectl get constrainttemplate

# run the saveenv.sh script at any time to save environment variables created above to aks_baseline.env
  ./saveenv.sh

# if your terminal session gets reset, you can source the file to reload the environment variables
# source aks_baseline.env

# Step 09 - Configure AKS ingress controller with Azure Key Vault integration

INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID=$(az deployment group show --resource-group rg-bu0001a0008 -n cluster-stamp --query properties.outputs.aksIngressControllerPodManagedIdentityClientId.value -o tsv)
echo INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID

# press Ctrl-C once you receive a successful response
kubectl get ns a0008 -w

cat <<EOF | kubectl create -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: aks-ingress-tls-secret-csi-akv
  namespace: a0008
spec:
  provider: azure
  parameters:
    clientID: $INGRESS_CONTROLLER_WORKLOAD_IDENTITY_CLIENT_ID
    usePodIdentity: "false"
    useVMManagedIdentity: "false"
    keyvaultName: $KEYVAULT_NAME_AKS_BASELINE
    objects:  |
      array:
        - |
          objectName: traefik-ingress-internal-aks-ingress-tls
          objectAlias: tls.crt
          objectType: cert
        - |
          objectName: traefik-ingress-internal-aks-ingress-tls
          objectAlias: tls.key
          objectType: secret
    tenantID: $TENANTID_AZURERBAC_AKS_BASELINE
EOF

# Import ingress controller image hosted in public container registries
az acr import --source docker.io/library/traefik:v2.9.6 -n $ACR_NAME_AKS_BASELINE

kubectl create -f https://raw.githubusercontent.com/mspnp/aks-baseline/main/workload/traefik.yaml

# the following command should give "condition met" response
kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=traefik-ingress-ilb --timeout=90s

# Step 10 - Deploy the workload (ASP.NET Core Docker web app)

# for linux
sed -i "s/contoso.com/${DOMAIN_NAME_AKS_BASELINE}/" workload/aspnetapp-ingress-patch.yaml

# for MacOs
sed -i '' 's/contoso.com/'"${DOMAIN_NAME_AKS_BASELINE}"'/g' workload/aspnetapp-ingress-patch.yaml

kubectl apply -k workload/

kubectl wait -n a0008 --for=condition=ready pod --selector=app.kubernetes.io/name=aspnetapp --timeout=90s

kubectl get ingress aspnetapp-ingress -n a0008

kubectl run curl -n a0008 -i --tty --rm --image=mcr.microsoft.com/azure-cli --overrides='[{"op":"add","path":"/spec/containers/0/resources","value":{"limits":{"cpu":"200m","memory":"128Mi"}}},{"op":"add","path":"/spec/containers/0/securityContext","value":{"readOnlyRootFilesystem": true}}]' --override-type json  --env="DOMAIN_NAME=${DOMAIN_NAME_AKS_BASELINE}"

# From within the open shell now running on a container inside your cluster
curl -kI https://bu0001a0008-00.aks-ingress.$DOMAIN_NAME -w '%{remote_ip}\n'
exit

# Step 11 - End-to-end validation

# query the Azure Application Gateway Public Ip
APPGW_PUBLIC_IP=$(az deployment group show --resource-group rg-enterprise-networking-spokes -n spoke-BU0001A0008 --query properties.outputs.appGwPublicIpAddress.value -o tsv)
echo APPGW_PUBLIC_IP: $APPGW_PUBLIC_IP

cat <<EOF | kubectl create -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aspnetapp-ingress-violating
  namespace: a0008
spec:
  tls:
  - hosts:
    - bu0001a0008-00.aks-ingress.invalid-domain.com
  rules:
  - host: bu0001a0008-00.aks-ingress.invalid-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: aspnetapp-service
            port:
              number: 80
EOF

# Create an entry in public DNS zone for the following FQDN pointing to Application Gateway IP by creating an A-Record in DNS.
# bicycle.domain-name.com

# To test the entire deployment to AKS, go to the following URL
https://bicycle.domain-name.com/



AzureDiagnostics
| where ResourceProvider == "MICROSOFT.NETWORK" and Category == "ApplicationGatewayFirewallLog"

ContainerLogV2
| where ContainerName == "aspnet-webapp-sample"
| project TimeGenerated, LogMessage, Computer, ContainerName, ContainerId
| order by TimeGenerated desc

ContainerRegistryRepositoryEvents
| where OperationName == 'Pull'

# 12 - Clean up
# BE EXTRA CAREFUL WITH THE FOLLOWING COMMANDS AS THIS WILL DELETE EVERTYTHING WE JUST PROVISIONED WITHOUT CONFIRMATION
# az group delete -n rg-bu0001a0008 --yes --no-wait
# az group delete -n rg-enterprise-networking-spokes --yes --no-wait
# az group delete -n rg-enterprise-networking-hubs --yes --no-wait

# az keyvault purge -n $KEYVAULT_NAME_AKS_BASELINE

# ------------------------------------------------------------------------------------------

# 13 - In case if ACR is not attached to AKS, use the following command
az aks update --name  aks-resource-name --resource-group rg-bu0001a0008 --attach-acr /subscriptions/subscriptionID/resourceGroups/rg-bu0001a0008/providers/Microsoft.ContainerRegistry/registries/acraksname

