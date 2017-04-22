#login to your azure account
Login-AzureRmAccount

#variable for VM creation
$firstname = "jason"
$resourceGroup = "GABPSLab"
$vmName = "GABPSLabVM" + $firstname
$location = "eastus"

#create a new resource group to use
New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create a subnet configuration
$subnetConfig = New-AzureRmVirtualNetworkSubnetConfig -Name GABVMSubNet -AddressPrefix 192.168.1.0/24

# Create a virtual network
$vnet = New-AzureRmVirtualNetwork -ResourceGroupName $resourceGroup -Location $location `
-Name GABVMVNet -AddressPrefix 192.168.0.0/16 -Subnet $subnetConfig

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
-AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "GABPSLabIP" + $firstname

# Create an inbound network security group rule for port 3389
$nsgRuleRDP = New-AzureRmNetworkSecurityRuleConfig -Name GABVMLabNetworkSecurityGroupRuleRDP  -Protocol Tcp `
-Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
-DestinationPortRange 3389 -Access Allow

# Create an inbound network security group rule for port 80 for HTTP
$nsgRuleWeb = New-AzureRmNetworkSecurityRuleConfig -Name GABVMLabNetworkSecurityGroupRuleWWW  -Protocol Tcp `
-Direction Inbound -Priority 1010 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
-DestinationPortRange 80 -Access Allow

# Create an inbound network security group rule for port 8172 for WebDeploy
$nsgRuleWebDeploy = New-AzureRmNetworkSecurityRuleConfig -Name GABVMLabNetworkSecurityGroupRuleWebDeploy  -Protocol Tcp `
-Direction Inbound -Priority 1020 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
-DestinationPortRange 8172 -Access Allow

# Create a network security group
$nsg = New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location eastus `
-Name GABVMLabNSG -SecurityRules $nsgRuleRDP,$nsgRuleWeb,$nsgRuleWebDeploy

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name GABPSNic -ResourceGroupName $resourceGroup -Location $location `
-SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Define a credential object
$cred = Get-Credential

# Create a virtual machine configuration
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize Standard_DS2 | `
Set-AzureRmVMOperatingSystem -Windows -ComputerName $vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2016-Datacenter -Version latest | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

# Install IIS and WebDeploy
$PublicSettings = '{"ModulesURL":"https://github.com/JasonHaley/GlobalAzureBootcamp/raw/master/ConfigureWebServer.ps1.zip", "configurationFunction": "ConfigureWebServer.ps1\\Main", "Properties": {"nodeName": "' + $vmName + '"} }'

Set-AzureRmVMExtension -ExtensionName "DSC" -ResourceGroupName $resourceGroup -VMName $vmName `
  -Publisher "Microsoft.Powershell" -ExtensionType "DSC" -TypeHandlerVersion 2.24 `
  -SettingString $PublicSettings -Location $location

$ipaddress = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup | Select -ExpandProperty IpAddress

# Launch RDP session
mstsc /v:$ipaddress

# set variable for the location of your Visual Studio Solution file
$solutionPath = "C:\_junk\GABWebApp\GABWebApp.sln"
$solutionName = "WebApplication2.sln"
$user = $vmName + "\" + $cred.UserName
$password = $cred.Password
$msbuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"

# build and publish to site
& $msbuild $solutionPath /p:DeployOnBuild=true /p:PublishProfile=CustomProfile /p:AllowUntrustedCertificate=True /p:User=$user /p:Password=$password
