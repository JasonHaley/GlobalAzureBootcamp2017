#login to your azure account
Login-AzureRmAccount

#variable for WebApp creation
$firstname = "jason"
$resourceGroup = "GABPSLab"
$location = "eastus"
$webappname="gabpswebapp" + $firstname

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
$profileName = $webappname + " - Web Deploy"

# set variable for the location of your Visual Studio Solution file
$solutionPath = "C:\_junk\GABWebApp\GABWebApp.sln"
$solutionName = "WebApplication2.sln"
$msbuild = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe"

# Use msbuild to build and deploy the solution to the web app
& $msbuild $solutionPath /p:DeployOnBuild=true /p:AllowUntrustedCertificate=True /p:PublishProfile=$profileName /p:User=$username /p:Password=$password
