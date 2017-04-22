#login to your azure account
Login-AzureRmAccount

#variable for resource group
$resourceGroup = "GABPSLab"

# remove all resources in resource group
Remove-AzureRmResourceGroup -ResourceGroupName $resourceGroup