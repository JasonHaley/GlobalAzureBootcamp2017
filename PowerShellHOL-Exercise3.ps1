#login to your azure account
Login-AzureRmAccount

#variable for Db creation
$firstname = "jason"
$resourceGroup = "GABPSLab"
$location = "eastus"
$servername = "gabdbpsserver" + $firstname
$databasename = "gabdbps" + $firstname
$adminlogin = "ServerAdmin"
$password = "ChangeYourAdminPassword1"


#Get your client ip
$externalIp = Invoke-WebRequest ifconfig.me/ip | Select -ExpandProperty Content 
$externalIp = $externalIp -replace "`t|`n|`r",""
$externalIp =  $externalIp -replace  " ;|; ",";"

# Create the server
New-AzureRmSqlServer -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -Location $location `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminlogin, $(ConvertTo-SecureString -String $password -AsPlainText -Force))

# Add a firewall rule
New-AzureRmSqlServerFirewallRule -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -FirewallRuleName "AllowSome" -StartIpAddress $externalIp -EndIpAddress $externalIp

# Create a new database
New-AzureRmSqlDatabase  -ResourceGroupName $resourceGroup `
    -ServerName $servername `
    -DatabaseName $databasename `
    -RequestedServiceObjectiveName "S0"

# Use PowerShell to create a login for the web app
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

