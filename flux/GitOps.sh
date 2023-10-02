# 1 - Create a new flux repo
az k8s-configuration flux create --resource-group rg-bu0001a0008 `
--cluster-name aks-fx7h5e6qdj4sg `
--name cluster-config `
--namespace cluster-config `
--cluster-type managedClusters `
--scope cluster `
--url https://dev.azure.com/nouman-msft/Prototypes/_git/aks-baseline-ado `
--branch main `
--kustomization name=infra path=./infrastructure prune=true `
--kustomization name=apps path=./apps/staging prune=true dependsOn=\["infra"\]

# 2 - Check the final compliance state. It should be "Compliant"
az k8s-configuration flux show -g flux-demo-rg -c flux-demo-arc -n cluster-config -t connectedClusters

# 3 - To confirm that the deployment was successful
az k8s-configuration flux show -g flux-demo-rg -c flux-demo-arc -n cluster-config -t connectedClusters

