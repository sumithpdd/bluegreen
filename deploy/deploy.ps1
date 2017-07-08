#
# Builds ASP.NET apps, deploys code for the web app onto the prior-deployed Azure infrastructure on Appp Service
#

[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)]
  [string]$SubscriptionId,
  
  [Parameter(Mandatory=$True)]
  [string]$RGName,
  
  [Parameter(Mandatory=$True)]
  [string]$WebAppName
)

# Determine current working directory:
$invocation = (Get-Variable MyInvocation).Value
$directorypath = Split-Path $invocation.MyCommand.Path
$parentDirectoryPath = (Get-Item $directorypath).Parent.FullName

# Constants:
$webAppPublishingProfileFileName = $directorypath + "\SPD-Belguimdemo.publishsettings"
echo "web publishing profile will be stored to: $webAppPublishingProfileFileName"

# Determine which directory to deploy:
$sourceDirToBuild = $parentDirectoryPath + "\src\BlueGreenUI\BlueGreenUI"
echo "source directory to build: $sourceDirToBuild"

# Build the BlueGreenUI ASP.NET sample web app:
Nuget.exe restore "$parentDirectoryPath\src\BlueGreenUI"
& "$(Get-Content env:windir)\Microsoft.NET\Framework\v4.0.30319\MSBuild.exe" `
 "$sourceDirToBuild\BlueGreenUI.csproj"  /p:DeployOnBuild=false /p:PublishProfile="bluegreenui" /p:VisualStudioVersion=14.0


# Select Subscription:
Get-AzureRmSubscription -SubscriptionId "$SubscriptionId" | Select-AzureRmSubscription
echo "Selected Azure Subscription"

# Fetch publishing profile for web app:
Get-AzureRmWebAppPublishingProfile -Name $WebAppName -OutputFile $webAppPublishingProfileFileName -ResourceGroupName $RGName
echo "Fetched Azure Web App Publishing Profile: bluegreenui.publishsettings"

# Parse values from .publishsettings file:
[Xml]$publishsettingsxml = Get-Content $webAppPublishingProfileFileName
$websiteName = $publishsettingsxml.publishData.publishProfile[0].msdeploySite
echo "web site name: $websiteName"

$username = $publishsettingsxml.publishData.publishProfile[0].userName
echo "user name: $username"

$password = $publishsettingsxml.publishData.publishProfile[0].userPWD
echo "password: $password"

$computername = $publishsettingsxml.publishData.publishProfile[0].publishUrl
echo "computer name: $computername"

# Deploy the web app ui
$msdeploy = "C:\MicrosoftWebDeployV3\msdeploy.exe"

$msdeploycommand = $("`"{0}`" -verb:sync -source:contentPath=`"{1}`" -dest:contentPath=`"{2}`",computerName=https://{3}/msdeploy.axd?site={4},userName={5},password={6},authType=Basic"   -f $msdeploy, $sourceDirToBuild, $websiteName, $computername, $websiteName, $username, $password)

cmd.exe /C "`"$msdeploycommand`"";
