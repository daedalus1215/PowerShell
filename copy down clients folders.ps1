﻿# Creator: Laurence F. Adams III 
# Febuary 23 2016
# Large Contributor and initial author: Bryan Kelley 

# This makes sure that we go to FileShare, go to a specific folder to grab all sub folders (affiliates client records), bring the folders down to a temporary folder, where we backup and move the files to the appropriate location.
# We repeat these steps for another sub folder (Administrative).

# Citrix FileShare dependency
Add-PSSnapin ShareFile

#################################################################################################################################
#################################################### CONSTANTS ##################################################################
#################################################################################################################################
#Credential path and initial processing location.
$PROCESS_LOCATION = "\Scripts\PowerShell\Affiliate Scraping\";

# Create the profile to automate this process.
#$sfClient = New-SfClient -Name ((Join-Path D: $PROCESS_LOCATION) + "sweetser.sfps") -Account YourSubdomain

# Use the previously created profile to run this script.
# Client Profile - The ASyncAffiliate Account.                                                                                                           #Change Build profile
$sfClient = GET-SfClient -Name ((Join-Path D: $PROCESS_LOCATION) + "sweetser.sfps");

# Directory IDs.
# FileShare directories
$AFFILIATE_FOLDER = 'FOLDER-ID-FOR-RECREATING-AFILLIATE-FOLDER-STRUCTURE'; # directory for the affiliates.                                                              
$ADMINISTRATIVE = 'FOLDER-ID-FOR-RECREATING-AFILLIATE-FOLDER-STRUCTURE'; # directory we are grabbing the administrative folders from                                   

# Path to FileShare admin and named directories, immediately after the /root/
$FILESHARE_AFFILIATE_FOLDER_PATH = "/PATH/TO/AFFILIATE/FOLDER/";                                                                      
$FILESHARE_ADMINISTRATIVE_PATH = "/PATH/TO/ADMIN/FOLDER/";                                                                    

# Destinations on server or local machine
$DOWNLOAD_PATH = (Join-Path  D: $PROCESS_LOCATION); # root directory for the following three.                                                          
$DOWNLOAD_TEMP_PATH = $DOWNLOAD_PATH + "temp"; # Stores the directories being processed by this script, temporarily, before the files get to the backup. 
# Client Records
$DOWNLOAD_PROCESSING = $DOWNLOAD_PATH + "Processing"; # Destination for all other paperwork to be processed                                              
$DOWNLOAD_BACKUP_PATH = $DOWNLOAD_PATH + "Backup"; # Destination for backup - Client Records backup path                                                 
# Admin
$DOWNLOAD_ADMIN = $DOWNLOAD_PATH + "Administrative"; # Destination for administrative paperwork                                                          
$DOWNLOAD_BACKUP_PATH_ADMIN = '\\server_name\path\for\Administrative\Backups'; # This is Jan's directory for admin backups.

# CHANGE - We need a corresponding folder name for each parent that is being scraped - Because when we pull down all affiliates client records from their parent folder (Affiliates), the parent directory comes down too.
$LOCAL_AFFILIATES = "\affiliates test";                                                                                                                 
$LOCAL_ADMINISTRATIVE = "\Administrative test";                                                                                                         

# Affiliate denoting variable. - There are clients that are not affiliates (who this script ought not to affect) and so we compare the company the user is in before we create their folders at the end of the script.

$LOG_PATH = "path\to\logging\error_logs.txt"; 

#################################################################################################################################
#################################################### FUNCTIONS ##################################################################
#################################################################################################################################

# Connect to the affiliate folders or their admin folders, just go to the parent folder and grab all of the folders inside.
# Argument: $fromPath - For us this is either the administrative or the named parent folder on FileShare.
# Argument: $destPath - For us this will be the same temporary folder ($tempPath)
function getFilesFromShareFile($fromPath, $destPath) {

    Write-Host "Connecting to ShareFile and syncing files..."; # could log this
    try { 
        $ShareFileHomeFolder = "sfdrive:/" + (Send-SfRequest $sfClient -Entity Shares).Name + $fromPath;

        # Create a PowerShell provider for ShareFile at the location specified.
        New-PSDrive -Name sfDrive -PSProvider ShareFile -Client $sfClient -Root "/" 

        # Cut / paste files from a sub-folder in ShareFile to a local folder.
        Sync-SfItem -ShareFilePath $ShareFileHomeFolder -Download -LocalPath $destPath -Recursive -Move   # -KeepFolders - include if we just wanted to copy and paste
    }catch {
        Add-Content $LOG_PATH "`nERROR cutting files from: {$fromPath} and sending to to: {$destPath}";
    }

    # Cleanup - remove the PSProvider
    Remove-PSDrive sfdrive

    Write-Host "Closing connection to ShareFile and syncing files..."; # could log this
}

# Lets take a backup shot of the folder structure and files of a specific directory ($dirToBackup). We can handle two types of backing-up structures - 
# affiliate named or admin folders. If we are backing up affiliates name (first iteration) we do not have a previous folder path (i.e. a folder already created with the
# current date and time - $pathOfPreviousFolder), and so we must create one. The second iteration we have a path where we have already stored the affiliates named folders and so we are going to 
# save the administrative folders structures in the same place as the named folders.
#
# Argument: $dirToBackup - Path to the directory we are backing up.
# Argument: $backupDestinationPath - Path where we are dumping this backup.
function takeBackupSnapshot($dirToBackup, $backupDestinationPath) {
    Write-Host "`nTaking backup snapshot...";
    #TROUBLESHOOTING - Write-Host "Backup path is: " + $backupPath; # Could log this
    #TROUBLESHOOTING - Write-Host "DIrectory to backup: " + $dirToBackup; # Could log this

        #TROUBLESHOOTING - Write-Host "Path of previous folder = false"; # Could log this if we wanted.

    # Create a new sub-dir with the yyyy-MM-dd as the name.
    $date = Get-Date -Format yyyy-MM-dd" "hh_mm_ss;
    $date = $date.ToString();
    $newFolder = "${backupDestinationPath}\${date}";
    #TROUBLESHOOTING - Write-Host "New folder is " + $newFolder; # Could log this if we wanted.
    
    try {
        # Create the new folder.
        New-Item -ItemType Directory -Path $newFolder | Out-Null; # Out-Null = supress output from New-Item
    } catch {
        Add-Content $LOG_PATH "`nERROR Creating backup folder for : {$newFolder}"; #$A = Get-Date; Add-Content c:\scripts\*.log $A 
    }

    # Needed so that the script doesn't copy the $newFolder itself. 
    # This will allow it to only copy the contents of $dirToBackup
    $dirToBackup = $dirToBackup;
    
    # Copy the all the files and their folders into this new folder we created or folder path we passed in as an argument.
    try {
        Copy-Item $dirToBackup $newFolder -Recurse;
    } catch {
        Add-Content $LOG_PATH "`nERROR Moving our backup: {$dirToBackup} to: {$newFolder}"; 
    }
    Write-Host "Backup snapshot complete.";

    # Return for the second time we call this function, that way we have a reference to it.
    #return $newFolder; # Do not need since we are using Jan's folder for this.
}

# We remove the folder Structure of a folder (so all the affiliates named or administrative folders from the temporary folder)
# Argument $pathToClean - is the source, the folder where all the affiliates folders are.
# Argument $destination - is the destination we are dumping the affiliate files into, whether administrative (director of affiliates) or ASync (Client Records)
function removeLocalFolderStructureAndMove($pathToClean, $destination) {
    $files = Get-ChildItem -Path $pathToClean -Recurse

    foreach ($file in $files)
    {
        $currentFilePath = $file.FullName

        if (!($file.PsIsContainer))
        {

            $outputPath = (Get-Item $destination);
            

            $currentFileName = [System.IO.Path]::GetFileName($file)
            $currentFileExt = [System.IO.Path]::GetExtension($file)

            $newFileName = getUniqueFileName "${outputPath}\${currentFileName}"
            $newFilePath = "${outputPath}\${newFileName}${currentFileExt}"
            try {
                Copy-Item $currentFilePath $newFilePath -Recurse;
            }catch {
                Add-Content $LOG_PATH "`nERROR Creating backup from: {$dirToBackup} to: {$backupDestinationPath}"; #$A = Get-Date; Add-Content c:\scripts\*.log $A 
            }
            
        }
    }
    if ($pathToClean) {
        Remove-Item $pathToClean -Recurse;
    }
    
}

# Make sure we return a unique file name.
# Argument $filePath - the file and it's path, we will be appending randomized digits to its name if the name is not unique.
function getUniqueFileName($filePath) {
    $fileNameNoExt = [System.IO.Path]::GetFileNameWithoutExtension($filePath)

    if (Test-Path $filePath)
    {
        $fileExt = [System.IO.Path]::GetExtension($filePath)
        $fileParentDir = [System.IO.Path]::GetDirectoryName($filePath)

        do
        {            
            # Get the current file name without extension and append a random number from 0 to 9.
            $newFileName = $fileNameNoExt + [string](Get-Random -Minimum 0 -Maximum 9)

            $filePath = "${fileParentDir}\${newFileName}${fileExt}"

            if (!(Test-Path $filePath))
            {
                return $newFileName
            } 
        } until (!(Test-Path $newFileName)) 
    }
    else
    {
        return $fileNameNoExt
    }
}
# We build two types of folder structures, affiliate named folder structures in the affiliate folder (on fileshare), or we create the affiliate admin folder structures in the administrative folder (on fileshare).
# Argument $parentFolderId - the Id of the folder we are inserting all the affiliate folders into
# Argument $admin - Boolean, if this is $admin folder structure or just regular named affiliate folder structure.
function recreateAffiliateFolders($parentFolderId, $isAdmin) {
    # Grab the pool of clients.
    $sfUsers = Send-SfRequest -Client $sfClient -Entity Accounts/Clients;

    foreach ($sfUserId in $sfUsers) {
        # Need more details on the user, so we are expanding on the security.
        $sfUser = Send-SfRequest -Client $sfClient -Entity Users -Id $sfUserId.Id -Expand Security
        
        # Grab the Company the user belongs to.
        $company = $sfUser.Company.ToLower();
        $isConfirmed = $sfUser.IsConfirmed;
        
        # If domain == sweetser, then create a new directory for the affiliate.
        if ($company -eq 'sweetser' -and $isConfirmed) {
            
            # Get the names
            $firstName = $sfUser.FirstName;
            $lastName = $sfUser.LastName;
            $lastFirst = $lastName + ", " + $firstName;
            $clientDocsNamingConvention = " Client Docs";
            $adminDocsNamingConvention = " Admin Docs";

            #Write-Output("We got a sweetser Company individual! User with the name: " + $firstName + " Belongs to company: " + $company);
            
         
            
            # Check if we are making affiliate named or adminstrative folders.
            if ($isAdmin) {
                # Create folder object
                $folderInfo ='{
                    "Name":"'+ $lastFirst + $adminDocsNamingConvention +'", 
                    "Description":"This is your administrative folder. Put all administrative documentation in here."
                }';
            
            }
            else {
                # Create folder object
                $folderInfo ='{
                    "Name":"'+$lastFirst + $clientDocsNamingConvention + '", 
                    "Description":"This is your named affiliate folder. Put all consultation documentation in here."
                }';
            }
         
            
            # Use folder object and create the folder. 
            $folder = Send-SfRequest -Client $sfClient -Entity Items -Method POST -Id $parentFolderId -Navigation Folder -BodyText $folderInfo
            
            if(!$folder) { 
                Add-Content $LOG_PATH "`nERROR Creating issue: for affiliate {$lastFirst}"; #$A = Get-Date; Add-Content c:\scripts\*.log $A 
            }
                
            
            Write-Output($sfUser.Username); # Could log this if we wanted.

            # Create Access Control Object and send a Post request to the folder with a navigation to Access Controls.
            #$userPrincipal = New-Object ShareFile.Api.Models.Principal
            #$AccessControlEntry = New-Object ShareFile.Api.Models.AccessControl
        
            #$userPrincipal.Email = $sfUser.Username;
            #$AccessControlEntry.Principal = $userPrincipal;
            #$AccessControlEntry.CanDownload = $true;
            #$AccessControlEntry.CanUpload = $true;
            #$AccessControlEntry.CanDelete = $false;
            #$AccessControlEntry.CanView = $true;
            #Send-SfRequest -Client $CLIENT_CREDS -Method POST -Entity Items -Navigation AccessControls -Id $folder.Id -Body $AccessControlEntry 
        }    
    }
} 

#################################################################################################################################
#################################################### MAIN #######################################################################
#################################################################################################################################


#### Affiliates Named folder scraping.

# FILESHARE - Grab All affiliate folders then storing them into $tempPath location.
getFilesFromShareFile $FILESHARE_AFFILIATE_FOLDER_PATH $DOWNLOAD_TEMP_PATH;

# LOCAL - Backup all Affiliate folders.
$tempPathAfterDownload = $DOWNLOAD_TEMP_PATH + $LOCAL_AFFILIATES; # We have to append the name of the folder we pulled this from on fileshare, because the structure we pulled down is in this sub folder now.
takeBackupSnapshot $tempPathAfterDownload $DOWNLOAD_BACKUP_PATH ; # not an admin backup so we pass false

# LOCAL - Remove the sub folder structure and move the files into the Processing folder for Client Records.
removeLocalFolderStructureAndMove $tempPathAfterDownload $DOWNLOAD_PROCESSING;

# FILESHARE - Recreate the affiliate's named folders.
recreateAffiliateFolders $AFFILIATE_FOLDER $false; 


#########################################################################################################

### Affiliates Administrative folder scraping.

# FILESHARE - Grab all Administrative folders.
getFilesFromShareFile $FILESHARE_ADMINISTRATIVE_PATH $DOWNLOAD_ADMIN;

# LOCAL - Backup the Administrative folders.
$tempPathAfterDownload = $DOWNLOAD_ADMIN + $LOCAL_ADMINISTRATIVE;
takeBackupSnapshot $tempPathAfterDownload $DOWNLOAD_BACKUP_PATH_ADMIN; # backed up working good

# LOCAL - Remove the sub folder structure and move the administrative files into director of affiliates directory
removeLocalFolderStructureAndMove $tempPathAfterDownload $DOWNLOAD_ADMIN;

# FILESHARE - Recreate the affiliate's named folders.
recreateAffiliateFolders $ADMINISTRATIVE $true; 

#TROUBLESHOOTING Write-Output "Done"; # Could log this