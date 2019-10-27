# CICD-CMDeployApp
Script to handle applications (UWP only)(create, distribute, deploy, delete supersede) based on input from CI/CD pipline
   Requires Configuration Manager module, so it needs to run on a machine with CM console installed
   
# Prerequisites
The script uses Configuration Manager CMDlets, so it needs to run on a machine with Configuration Manager console installed.

# Deployment
The script has parameters:

CMSiteCode: 
Configuration Manager site code [mandatory]

CMProviderMachineName: 
Machine name of Configuration Manager SMSProvider to be used by the script [mandatory]

CMDistributionPointGroupName: 
Distribution Point Group for content distribution [mandatory]

DeployRootPath: 
Content source path that hosts CMSourceFolder [mandatory]

CMSourceFolder: 
Folder that contains all required content created by build process (appxbundle, dependencies) [mandatory]

BundleName: 
Name of the appxbundle [mandatory]

CMAppDisplayName: 
End user presented application name (UI: Localized application name) [mandatory]

CMAppVersion: 
Application version [mandatory]

CMAppName: 
Configuration Manager application name (UI: Name) [mandatory]

CMSupersededAppName: 
Application to be superseded, the script will supersede all apps starting with CMSupersededAppName is CMAppVersion is lower [mandatory]

CMAppCategory: 
Application category (UI: Administrative category) [mandatory]

Environment: 
CI/CD pipeline environment that created the release (deprecated) [mandatory]

CMAppIconName: 
Name of icon-file; file needs to exist in DeployRootPath\Icon folder [mandatory]

CMAppUserDocLink: 
URI to end user documentation, release notes (UI: User documentation)

CMAppUserDocText: 
Description of CMAppUserDocLink (UI: Link text)

CMAppFolder: 
Software Library folder to create the application in [mandatory]

CMCollectionNameAvl: 
if exists, an available deployment is created

CMCollectionNameMan: 
if exists, a mandatory deployment is created


# License
This project is licensed under the MIT License - see the LICENSE.md file for details
