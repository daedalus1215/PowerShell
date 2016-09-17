# Creator: Laurence F. Adams III 
# Febuary 23 2016
# Large Contributor and initial author: Bryan Kelley 
# Revised on March 24 2016 - because of error logging issues.


# This makes sure that we go to FileShare, go to a specific folder to grab all sub folders (affiliates client records), bring the folders down to a temporary folder, where we backup and move the files to the appropriate location.
# We repeat these steps for another sub folder (Administrative).



# Citrix FileShare dependency
Add-PSSnapin ShareFile


# The date.
$date = Get-Date -Format yyyy-MM-dd" "hh_mm_ss;






#Credential path 
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#Profile file
$profilePath = $scriptPath + "\profile.sfps";

# oAuth token and session for a FileShare Account.                                                                                               
$sfClient = GET-SfClient -Name $profilePath;

# local path
$tmpCopyPath = $scriptPath + "\temp_copy";

$logPath = $scriptPath + "\error_logs.txt";


# Directory IDs.
# FileShare directories
$AFFILIATE_FOLDER = 'fo026820-dd40-4aa4-95d3-ce27a09daaf6'; # directory for the affiliates.                                                            
$ADMINISTRATIVE = 'fodfbe4b-8299-48f4-b4f9-384e1affb970'; # directory we are grabbing the administrative folders from                                 

# Path to FileShare admin and named directories, immediately after the /root/
$fileShareAffiliateFolderPath = "/Affiliates & Client Records Test/Affiliates";                                                                       




function getFilesFromShareFile($fileSharePath, $localPath, $sfClient) 
{
    Add-Content $logPath "`nERROR {$date} - Connecting to ShareFile and Syncing Files."; 


    $ShareFileHomeFolder = "sfdrive:/" + (Send-SfRequest $sfClient -Entity Shares).Name + $fileSharePath;
        
    Write-Output("Share file path " + $ShareFileHomeFolder);

    # Create a PowerShell provider for ShareFile at the location specified.
    New-PSDrive -Name sfdrive -PSProvider ShareFile -Root \ -Client $sfClient;
        
    # Cut / paste files from a sub-folder in ShareFile to a local folder.
    Sync-SfItem -ShareFilePath $ShareFileHomeFolder -Download -LocalPath $localPath -Recursive -Move -KeepFolders -Overwrite # - include if we just wanted to copy and paste

    # Cleanup - remove the PSProvider
    Remove-PSDrive sfdrive

    Write-Host "Closing connection to ShareFile and syncing files..."; # could log this
}



# FILESHARE - Grab All affiliate folders then storing them into $tempPath location.
getFilesFromShareFile $fileShareAffiliateFolderPath $tmpCopyPath $sfClient;