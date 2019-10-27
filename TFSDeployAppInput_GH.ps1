<#
.Synopsis
   Script to handle applications (UWP only) (create, distribute, deploy, delete supersede) based on input from CI/CD pipline

.DESCRIPTION
   Script to handle applications (UWP only)(create, distribute, deploy, delete supersede) based on input from CI/CD pipline
   Requires Configuration Manager module, so it needs to run on a machine with CM console installed
   sigurd werner; 2018

.PARAMETER CMSiteCode
Configuration Manager site code [mandatory]
.PARAMETER CMProviderMachineName
Machine name of Configuration Manager SMSProvider to be used by the script [mandatory]
.PARAMETER CMDistributionPointGroupName
Distribution Point Group for content distribution [mandatory]
.PARAMETER DeployRootPath
Content source path that hosts CMSourceFolder [mandatory]
.PARAMETER CMSourceFolder
Folder that contains all required content created by build process (appxbundle, dependencies) [mandatory]
.PARAMETER BundleName
Name of the appxbundle [mandatory]

.PARAMETER CMAppDisplayName
End user presented application name (UI: Localized application name) [mandatory]
.PARAMETER CMAppVersion
Application version [mandatory]
.PARAMETER CMAppName
Configuration Manager application name (UI: Name) [mandatory]
.PARAMETER CMSupersededAppName
Application to be superseded, the script will supersede all apps starting with CMSupersededAppName is CMAppVersion is lower [mandatory]
.PARAMETER CMAppCategory
Application category (UI: Administrative category) [mandatory]
.PARAMETER Environment
CI/CD pipeline environment that created the release (deprecated) [mandatory]
.PARAMETER CMAppIconName
Name of icon-file; file needs to exist in DeployRootPath\Icon folder; based on a cmdlet-bug icon is limited to 250px x 250px [mandatory]
.PARAMETER CMAppUserDocLink
URI to end user documentation, release notes (UI: User documentation)
.PARAMETER CMAppUserDocText
Description of CMAppUserDocLink (UI: Link text)
.PARAMETER CMAppFolder
Software Library folder to create the application in [mandatory]

.PARAMETER CMCollectionNameAvl
if exists, an available deployment is created
.PARAMETER CMCollectionNameMan
if exists, a mandatory deployment is created

.EXAMPLE
TFSDeployAppInput_GH.ps1 -CMSiteCode PRD -CMProviderMachineName siteserver.sw2demotenant.local -DeployRootPath '\\sw2demotenant.local\its\cmcb\DML\Applications\PROD\SW2Demo\CICD' -CMSourceFolder 'BLP_SDX_SGS.NewTimeTrack.AppPackage_2.0.0.13910_Test -BundleName BLP_SDX_SGS.NewTimeTrack.AppPackage_2.0.0.13910_x86.appxbundle -CMAppDisplayName 'TimeTrack BLP SDX 2.0.0.13911' -CMAppVersion 2.0.0.13911 -$CMAppName 'SW2 Demo App DEV 2.0.0.13911 [MUI]' -CMSupersededAppName 'SW2 Demo App DEV' -CMAppCategory CI/CD -Environment DEV -CMAppIconName ntt_devLogo.png -CMAppUserDocLink http://welcome.sw2demotenant.local/sites/telserv/collaboration/windows10/default.aspx -CMAppUserDocText 'Release Notes' -CMAppFolder PRD:\Application\CLT\SW2\CMIaaS\EUC -CMCollectionNameAvl 'EUC USR werners'

.Notes
A log-file CMAppName.log is created in LogFolder (default 'C:\ProgramData\CICD')
Publisher is set by $AppPublisher
Description is set by $AppDescription
Deployment Type is set by $DTName
based on $OlderVersionsToKeep = 2 existing application releases will be superseded, older application releases will be deleted including CMSourceFolder
#>



Param(
 [Parameter (Mandatory=$true)][string]$CMSiteCode,
 [Parameter (Mandatory=$true)][string]$CMProviderMachineName,
 [Parameter (Mandatory=$true)][string]$CMDistributionPointGroupName,
 [Parameter (Mandatory=$true)][string]$DeployRootPath,
 [Parameter (Mandatory=$true)][string]$CMSourceFolder,
 [Parameter (Mandatory=$true)][string]$BundleName,

 [Parameter (Mandatory=$true)][string]$CMAppDisplayName,
 [Parameter (Mandatory=$true)][string]$CMAppVersion,
 [Parameter (Mandatory=$true)][string]$CMAppName,
 [Parameter (Mandatory=$true)][string]$CMSupersededAppName,
 [Parameter (Mandatory=$true)][string]$CMAppCategory,
 [Parameter (Mandatory=$true)][string]$Environment,
 [Parameter (Mandatory=$true)][string]$CMAppIconName,
 [Parameter (Mandatory=$false)][string]$CMAppUserDocLink,
 [Parameter (Mandatory=$false)][string]$CMAppUserDocText,
 [Parameter (Mandatory=$true)][string]$CMAppFolder,

 [Parameter (Mandatory=$false)][string]$CMCollectionNameAvl,
 [Parameter (Mandatory=$false)][string]$CMCollectionNameMan
)

#ErrorActionPreference

# Prepare some paths and logfile per application
$CMAppNameFull = $CMAppName
$CMContentSourceFolder = "$DeployRootPath\$CMSourceFolder"
$CMContentSource = "$CMContentSourceFolder\$BundleName"
$CMIconSourceFolder = "$DeployRootPath\Icon"
$CMIconLocation = "$CMIconSourceFolder\$CMAppIconName"

# Some hardcoded settings
$AppPublisher = "The SW2 Demo App Publisher"
$OlderVersionsToKeep = 15
$DTName = "appx"

$VersionsList = @{}

# Prepare log-file
$LogFolder = "FileSystem::\\sw2demotenant.local\its\CICD_Project\TFSDeployAppInputLogs"
$Logfile = $CMAppName | ForEach-Object {$_ -replace " ", "_"}
$LogPath = "$LogFolder\$Logfile.log"
if (!(Test-Path -LiteralPath $LogPath)) {
    New-Item -Path $LogPath  -ItemType file -Force
}
$MyInvocation.MyCommand

# Log parameters and values
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Execute = $PSCommandPath"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMSiteCode = $CMSiteCode"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMProviderMachineName = $CMProviderMachineName"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMDistributionPointGroupName = $CMDistributionPointGroupName"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) DeployRootPath = $DeployRootPath"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMSourceFolder = $CMSourceFolder"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) BundleName = $BundleName"

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppDisplayName = $CMAppDisplayName"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppVersion = $CMAppVersion"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppName = $CMAppName"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMSupersededAppName = $CMSupersededAppName"

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppCategory = $CMAppCategory"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Environment = $Environment"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppIconName = $CMAppIconName"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppUserDocLink = $CMAppUserDocLink"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppUserDocText = $CMAppUserDocText"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMAppFolder = $CMAppFolder"

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMCollectionNameAvl = $CMCollectionNameAvl"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMCollectionNameMan = $CMCollectionNameMan"

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMContentSource = $CMContentSource"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) CMIconLocation = $CMIconLocation"

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) OlderversionToKeep = $OlderVersionsToKeep"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) DefaultDeploymentTypeName = $DTName"



Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start initialization step"
# Customizations
$initParams = @{}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Initialzed"
#$initParams.Add("Verbose", $true)
#$initParams.Add("ErrorAction", "Stop")

# Import the ConfigurationManager.psd1 module 
if(!(Get-Module ConfigurationManager)) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1" @initParams 
}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) PoSh module loaded"

# Connect to the site's drive if it is not already present
if(!(Get-PSDrive -Name $CMSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue)) {
    New-PSDrive -Name $CMSiteCode -PSProvider CMSite -Root $CMProviderMachineName @initParams
}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Connected to CM site"

# Set the current location to be the site code.
Set-Location "$($CMSiteCode):\" @initParams

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set location = $CMSiteCode"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished initialization step"


Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start Application Category step"
# Create a New Application Category if it doesn't exist
if(!(Get-CMCategory -Name $CMAppCategory)) {
    New-CMCategory -CategoryType AppCategories -Name $CMAppCategory
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Created Application Category = $CMAppCategory"
}
else {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Category already exists = $CMAppCategory"
}
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished Application Category step"


# Create a new Application if it doesn't exist
try {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start application creation step"
    if (!(Get-CMApplication -Name $CMAppName)) {
        If ($CMAppUserDocLink -and $CMAppUserDocText) {
            if (New-CMApplication -Name $CMAppName -Description "CI/CD auto created" -Publisher $AppPublisher -SoftwareVersion $CMAppVersion -LocalizedName $CMAppDisplayName -IconLocationFile $CMIconLocation -UserDocumentation $CMAppUserDocLink -LinkText $CMAppUserDocText ) {
                # Create application w/ documentation link parameters
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) New-CMApplication w/ doc created = $CMAppName"
            }
            else {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) New-CMApplication w/ doc failed on = $CMAppName"
            }
        }
        else {
            if (New-CMApplication -Name $CMAppName -Description "CI/CD auto created" -Publisher $AppPublisher -SoftwareVersion $CMAppVersion -LocalizedName $CMAppDisplayName -IconLocationFile $CMIconLocation) {
                # Create application w/o documentation link parameters
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) New-CMApplication w/o doc created = $CMAppName"
            }
            else {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) New-CMApplication w/o doc failed on = $CMAppName"
            }
        }
    }
    else {
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Application already exists = $CMAppName"
    }
    
    $AppInputObject = (Get-CMApplication -Name $CMAppName)
    if ($AppInputObject) {
        # Change properties that cannot set on New-CmApplication
        Set-CMApplication -InputObject $AppInputObject -AppCategory $CMAppCategory -ReleaseDate (get-date)
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set Application Category = $CMAppCategory"
        
        # Move application to folder since it is always created in the root
        $AppInputObject = (Get-CMApplication -Name $CMAppName)
        Move-CMObject -FolderPath $CMAppFolder -InputObject $AppInputObject
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Moved application to = $CMAppFolder"
    }
    
    if (!(Get-CMDeploymentType -ApplicationName $CMAppName -DeploymentTypeName $DTName)) {
        # Add the Deployment type automatically from the appx 
        $AppInputObject = (Get-CMApplication -Name $CMAppName)
        if (Add-CMWindowsAppxDeploymentType -InputObject $AppInputObject -DeploymentTypeName $DTName -ContentLocation $CMContentSource -SlowNetworkDeploymentMode Download -ContentFallback) {
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Create Deployment Type = $DTName from $CMContentSource"
        }
        else {
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Create Deployment Type failed on = $DTName from $CMContentSource"
        }
    }
    else {
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Deployment Type already exists = $DTName from $CMContentSource"
    }
}
catch {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed to create Application = $CMAppName"
    Write-Error -Message "Fatal error in Application creation"
    exit 1
}
finally {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished application creation step" 
}

    
#Distribute the Content to the DP Group
try {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start content distribution step" 
    $AppInputObject = (Get-CMApplication -Name $CMAppName)
    $ContentStatus = Get-CMDistributionStatus -InputObject $AppInputObject
    if ((($ContentStatus).NumberSuccess -eq 0) -and (($ContentStatus).NumberInProgress -eq 0)) {
        # No sucessfull or running content distribution
        # Distribute content
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Content does not exist on = $CMDistributionPointGroupName"
        Start-CMContentDistribution -ApplicationName $CMAppNameFull -DistributionPointGroupName $CMDistributionPointGroupName
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Distributed content to = $CMDistributionPointGroupName"
    }
    else {
        # Content already exists
        # Update content
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Content does exist on = $CMDistributionPointGroupName"
        Update-CMDistributionPoint -ApplicationName $CMAppName -DeploymentTypeName $DTName
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Updated content on = $CMDistributionPointGroupName"
    }
}
catch {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed content distribution to = $CMDistributionPointGroupName"
    Write-Error -Message "Fatal error in distributing content"
    exit 1
}
finally {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished content distribution step" 
}
    
    
# Handle older versions of this application
# Since the application naming standard incl. the version in the name e.g. "DemoApp 1.1"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start list older applications step"
$ApplicationNameWildcard = $CMSupersededAppName + "*"

# Delete older versions except number to be kept
# Find all versions of the app e.g. "DemoApp*"
$ApplicationsOld = Get-CMApplication -Name $ApplicationNameWildcard -ForceWildcardHandling

# Create hash table of older versions (name=SoftwareVersion value=LocalizedDisplayName ) to sort by version
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Create hash table"
foreach ($Application in $ApplicationsOld) {
    if ([System.Version]$Application.SoftwareVersion -lt [System.Version]$CMAppVersion) {
        $VersionsList.Add([System.Version]$Application.SoftwareVersion, $Application.LocalizedDisplayName)
    }
}

# Sort hash table by version
$VersionsListSorted = $VersionsList.GetEnumerator() | Sort-Object -Property Name -Descending
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Sorted hash table"
Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished list older applications step"

# If more older versions exist: delete
try {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start application deletion step"
    if ($VersionsListSorted.Count -gt $OlderVersionsToKeep) {
        for ($i=$OlderVersionsToKeep; $i -lt $VersionsListSorted.Count; $i++) {
            $AppPrint = $VersionsListSorted[$i].Value
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Delete all of $AppPrint"
    
            # Delete Deployemts
            $Deployments = Get-CMDeployment -SoftwareName $VersionsListSorted[$i].Value
            foreach ($Deployment in $Deployments) {
                Remove-CMDeployment -DeploymentId $Deployment.DeploymentID -ApplicationName $VersionsListSorted[$i].Value -Force -ErrorAction SilentlyContinue -ErrorVariable FailedAction
                if (!($FailedAction)) {
                    $DeploymentIDPrint = $Deployment.DeploymentID
                    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Deleted Deployment $DeploymentIDPrint of $AppPrint"
                }
                else {
                    $DeploymentIDPrint = $Deployment.DeploymentID
                    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed to deleted Deployment $DeploymentIDPrint of $AppPrint"
                }
            }
            
            # Get Deployments Types to delete content folder
            $AppObj = Get-CMApplication -Name $VersionsListSorted[$i].Value
            $AppXML = ([xml]$AppObj.SDMPackageXML).AppMgmtDigest
            foreach ($DTXML in $AppXML.DeploymentType) {
                $DTContentLocation = $DTXML.Installer.Contents.Content.Location
                Set-Location -LiteralPath FileSystem::$DeployRootPath
                Remove-Item -LiteralPath $DTContentLocation -Force -Recurse -ErrorAction SilentlyContinue
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Deleted Content Folder = $DTContentLocation"
            }

            # Delete Application
            Set-Location "$($CMSiteCode):\"
            Remove-CMApplication -Name $VersionsListSorted[$i].Value -Force
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Deleted Application = $AppPrint"
        } 
    }
}
catch {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed to delete all of $AppPrint"
    Write-Error -Message "Fatal error in delete older releases"
    exit 1
}
finally {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished application deletion step" 
}


# Set supersedence for not deleted application
# Find all versions of the app e.g. "DemoApp*"
try {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start supersedence step"
    $ApplicationsOld = Get-CMApplication -Name $ApplicationNameWildcard -ForceWildcardHandling

    # For every older version 
    foreach ($Application in $ApplicationsOld) {
        if ([System.Version]$Application.SoftwareVersion -lt [System.Version]$CMAppVersion) {
            $ApplicationOldName = $Application.LocalizedDisplayName
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Superseding Application = $ApplicationOldName"
                    
            # Get all Deployment Types of this older application version
            $ApplicationOldDTs = Get-CMDeploymentType -ApplicationName $ApplicationOldName
            
            # For every Deployment Type
            foreach ($ApplicationOldDT in $ApplicationOldDTs) {
                # Since adding a supersedence is changing the new Deployment Type, the Deployment Type needs to be reloaded for additional supersedeces
                $ApplicationNewDT = Get-CMDeploymentType -ApplicationName $CMAppName -DeploymentTypeName $DTName            
                
                # Supersede old application Deployment Type
                if (Add-CMDeploymentTypeSupersedence -SupersededDeploymentType $ApplicationOldDT -SupersedingDeploymentType $ApplicationNewDT -IsUninstall $false) {
                    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Superseding Deployment Type = $($ApplicationOldDT.LocalizedDisplayName)"
                }
                else {
                    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Superseding Deployment Type failed = $($ApplicationOldDT.LocalizedDisplayName)"
                }
            }
        }
    } 
}
catch {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed to superseed all of $ApplicationNameWildcard"
    Write-Error -Message "Fatal error in superseding older releases"
    exit 1
}
finally {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished supersedence step"
}


# If collection exists create available deployment
try {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start available deployment step"
    if ($CMCollectionNameAvl) {
        if (!(Get-CMDeployment -CollectionName $CMCollectionNameAvl -SoftwareName $CMAppName)) {
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) No existing available deployment to = $CMCollectionNameAvl"
            if (New-CMApplicationDeployment -CollectionName $CMCollectionNameAvl -Name $CMAppNameFull -DeployAction Install -DeployPurpose Available -UserNotification DisplayAll -AvailableDateTime (get-date) -TimeBaseOn LocalTime -UpdateSupersedence $true) {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set available deployment to = $CMCollectionNameAvl"    
            }
            else {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set available deployment failed = $CMCollectionNameAvl"    
            }
        }
        else {
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Deployment already exists = $CMCollectionNameAvl"    
        }       
    }
    else {
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Available collection is empty"    
    }       
}
catch {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed to create deployment to = $CMCollectionNameAvl"
    Write-Error -Message "Fatal error in creating available deployments"
    exit 1
}
finally {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished available deployment step"
}


# If collection exists create mandatory deployment
try {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) -->Start mandatory deployment step"
    if ($CMCollectionNameMan) {
        if (!(Get-CMDeployment -CollectionName $CMCollectionNameMan -SoftwareName $CMAppName)) {
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) No existing mandatory deployment to = $CMCollectionNameMan"
            if (New-CMApplicationDeployment -CollectionName $CMCollectionNameMan -Name $CMAppNameFull -DeployAction Install -DeployPurpose Required -UserNotification DisplayAll -AvailableDateTime (get-date) -DeadlineDateTime (get-date) -TimeBaseOn LocalTime -UpdateSupersedence $true -OverrideServiceWindow $true) {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set mandatory deployment to = $CMCollectionNameMan"
            }
            else {
                Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Set mandatory deployment failed = $CMCollectionNameMan"
            }
        }
        else {
            Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Deployment already exists = $CMCollectionNameMan"    
        }
    }
    else {
        Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Mandatory collection is empty"    
    }
}
catch {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) Failed to create deployment to = $CMCollectionNameMan"
    Write-Error -Message "Fatal error in creating mandatory deployments"
    exit 1
}
finally {
    Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) <--Finished mandatory deployment step"
}

Add-Content -LiteralPath $LogPath -Value "$(Get-Date -Format o) End of Script"

