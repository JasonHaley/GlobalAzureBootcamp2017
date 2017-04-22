#check version oa PowerShellGet
Get-Module PowerShellGet -list | Select-Object Name,Version,Path

#if you don't have PowerShellGet: 
#https://docs.microsoft.com/en-us/powershell/azure/install-azurerm-ps?view=azurermps-3.8.0#how-to-get-powershellget

#check version of AzureRM
Get-Module AzureRM -list | Select-Object Name,Version,Path

#update version
Update-Module -Name AzureRM -Force

#if you don't have AzureRM then you can install it
Install-Module -Name AzureRM -AllowClobber

#login to your azure account
Login-AzureRmAccount

$resourceGroup = "GABPSLab"
$vmName = "GABPSLabVM"
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
-AllocationMethod Static -IdleTimeoutInMinutes 4 -Name "GABPSLab$(Get-Random)"

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
$PublicSettings = '{"ModulesURL":"https://github.com/JasonHaley/GlobalAzureBootcamp/raw/master/ConfigureWebServer.ps1.zip", "configurationFunction": "ConfigureWebServer.ps1\\Main", "Properties": {"nodeName": "GABPSLabVM"} }'

Set-AzureRmVMExtension -ExtensionName "DSC" -ResourceGroupName $resourceGroup -VMName $vmName `
  -Publisher "Microsoft.Powershell" -ExtensionType "DSC" -TypeHandlerVersion 2.24 `
  -SettingString $PublicSettings -Location $location

$ipaddress = Get-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup | Select -ExpandProperty IpAddress

# Launch RDP session
mstsc /v:$ipaddress

$solutionPath = "C:\_junk\GABWebApp\GABWebApp.sln"
$solutionName = "WebApplication2.sln"
$user = $vmName + "\jason"
$password = "ChiChi73!!ChiChi73!!"
$msbuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"

# build and publish to site
& $msbuild $solutionPath /p:DeployOnBuild=true /p:PublishProfile=CustomProfile /p:AllowUntrustedCertificate=True /p:User=$user /p:Password=$password

#Deploy to web app
$webappname="gabpswebapp"

# Create an App Service plan in Standard tier.
New-AzureRmAppServicePlan -Name $webappname -Location $location `
-ResourceGroupName $resourceGroup -Tier Standard

# Create a web app.
New-AzureRmWebApp -Name $webappname -Location $location `
-AppServicePlan $webappname -ResourceGroupName $resourceGroup

# Get publishing profile for the web app
$xml = [xml](Get-AzureRmWebAppPublishingProfile -Name $webappname `
-ResourceGroupName $resourceGroup `
-OutputFile null)

# Extract connection information from publishing profile
$username = $xml.SelectNodes("//publishProfile[@publishMethod=`"MSDeploy`"]/@userName").value
$password = $xml.SelectNodes("//publishProfile[@publishMethod=`"MSDeploy`"]/@userPWD").value

& $msbuild $solutionPath /p:DeployOnBuild=true /p:PublishProfile="gabpswebapp - Web Deploy" /p:AllowUntrustedCertificate=True /p:User=$username /p:Password=$password

#Create database server ---------------------------------------------------------------

$servername = "gabdbpsserver-$(Get-Random)"
$databasename = "gabdbpsjason"

# Set an admin login and password for your database
# The login information for the server
$adminlogin = "ServerAdmin"
$password = "ChangeYourAdminPassword1"


#Get your client ip
$externalIp = Invoke-WebRequest ifconfig.me/ip | Select -ExpandProperty Content 
$externalIp = $externalIp -replace "`t|`n|`r",""
$externalIp =  $externalIp -replace  " ;|; ",";"


New-AzureRmSqlServer -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -Location $location `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminlogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))

New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -FirewallRuleName "AllowSome" -StartIpAddress $externalIp -EndIpAddress $externalIp


New-AzureRmSqlDatabase  -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -DatabaseName $databasename `
    -RequestedServiceObjectiveName "S0"

$serverConnection = new-object Microsoft.SqlServer.Management.Common.ServerConnection
$serverConnection.ServerInstance=$servername + ‘.database.windows.net’
$serverConnection.LoginSecure = $false
$serverConnection.Login = $adminlogin
$serverConnection.Password = $password

[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null
$SqlServer = New-Object 'Microsoft.SqlServer.Management.Smo.Server' ($servername + ‘.database.windows.net’)

Add-Type -Path "C:\Program Files\Microsoft SQL Server\130\SDK\Assemblies\Microsoft.SqlServer.Smo.dll"
$SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($mySrvConn)

# get all of the current logins and their types
$SqlServer.Logins | Select-Object Name, LoginType, Parent

# create a new login by prompting for new credentials
$NewLoginCredentials = Get-Credential -Message "Enter credentials for the new login"
$NewLogin = New-Object Microsoft.SqlServer.Management.Smo.Login($SqlServer, $NewLoginCredentials.UserName)
$NewLogin.LoginType = [Microsoft.SqlServer.Management.Smo.LoginType]::SqlLogin
$NewLogin.Create($NewLoginCredentials.Password)
 
# create a new database user for the newly created login
$NewUser = New-Object Microsoft.SqlServer.Management.Smo.User($SqlServer.Databases[$databasename], $NewLoginCredentials.UserName)
$NewUser.Login = $NewLoginCredentials.UserName
$NewUser.Create()
$NewUser.AddToRole("db_datareader") 
$NewUser.AddToRole("db_datawriter") 
$NewUser.AddToRole("db_ddladmin") 



# remove all resources in resource group
Remove-AzureRmResourceGroup -ResourceGroupName $resourceGroup