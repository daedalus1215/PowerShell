# Author: Laurence F. Adams III 
# Febuary 23 2016
# Large Contributor and initial author: Bryan Kelley 
# Revised on March 24 2016 - by LA because of error logging issues.
# Revised on August 09 2016 - by LA 
#                           - 1. We want to make sure we still create the appropriate directories, even if a user has not verified their account.
#                           - 2. We want to introduce a regex for the Company logic, to take in account whitespaces and typos.

# This makes sure that we go to FileShare, go to a specific folder to grab all sub folders (affiliates client records), bring the folders down to a temporary folder, where we backup and move the files to the appropriate location.
# We repeat these steps for another sub folder (Administrative).



# Citrix FileShare dependency
Add-PSSnapin ShareFile



#################################################### CONSTANTS ##################################################################



#Credential path and initial processing location.
$PROCESS_LOCATION = "\path\where\script\is\located\and\temporary\directory\where\we\work\from";

$CLIENT_RECORDS_DESTINATION = '\path\to\client\records\directory';

# If we need to create the profile to automate this process. Then uncomment line below, before running the rest of the application.
#$sfClient = New-SfClient -Name ((Join-Path D: $PROCESS_LOCATION) + "credentials.sfps") -Account YourSubdomain


$sfClient = GET-SfClient -Name ((Join-Path D: $PROCESS_LOCATION) + "credentials.sfps");# Client Profile - The an Account on Citrix Fileshare.  Establish Session.


$AFFILIATE_FOLDER = 'FOLDER-ID-HERE';                                                      
$ADMINISTRATIVE = 'FOLDER-ID-HERE';                                


# Path to FileShare admin and named directories, immediately after the /root/
$FILESHARE_AFFILIATE_FOLDER_PATH = "/MAIN_FILE_SHARE_LOCATION/Affiliates";                                                                       
$FILESHARE_ADMINISTRATIVE_PATH = "/MAIN_FILE_SHARE_LOCATION/Administrative";                                                                     


# Destinations on server or local machine - not on citrix fileshare
$DOWNLOAD_PATH = (Join-Path  D: $PROCESS_LOCATION); # root directory for the following three.                                                            
$DOWNLOAD_TEMP_PATH = $DOWNLOAD_PATH + "temp"; # Stores the directories being processed by this script, temporarily, before the files get to the backup. 
#Client Records 
$DOWNLOAD_PROCESSING = $CLIENT_RECORDS_DESTINATION + "ShareFile Auto Sync"; # Destination for all other paperwork to be processed                                          
$DOWNLOAD_BACKUP_PATH = $CLIENT_RECORDS_DESTINATION + "ShareFile Auto Sync Backup"; # Destination for backup - Client Records backup path                              
#Admin 
$DOWNLOAD_ADMIN = '\\server\Departments\AffiliateNetworkProcessing\Admin'; 
$DOWNLOAD_BACKUP_PATH_ADMIN = '\\server\Departments\AffiliateNetworkProcessing\Backups';


$LOCAL_AFFILIATES = "\Affiliates";
$LOCAL_ADMINISTRATIVE = "\Administrative";


$LOG_PATH = (Join-Path  D: "$PROCESS_LOCATION\temp\") + "error_logs.txt"; 

$DATE = Get-Date -Format yyyy-MM-dd" "hh_mm_ss; # The date.





#################################################### FUNCTIONS ##################################################################



# Connect to the affiliate folders or their admin folders, just go to the parent folder and grab all of the folders inside.
# Argument: $fromPath - For us this is either the administrative or the named parent folder on FileShare.
# Argument: $destPath - For us this will be the same temporary folder ($tempPath)
function getFilesFromShareFile($fromPath, $destPath) {
    # Cut / paste files from a sub-folder in ShareFile to a local temporary folder.
    try { 
        $ShareFileHomeFolder = "sfdrive:/" + (Send-SfRequest $sfClient -Entity Shares).Name + $fromPath;
        
        New-PSDrive -Name sfDrive -PSProvider ShareFile -Client $sfClient -Root "/" # Create a PowerShell provider for ShareFile at the location specified.

        
        Sync-SfItem -ShareFilePath $ShareFileHomeFolder -Download -LocalPath $destPath -Recursive -Move   # -KeepFolders - include if we just wanted to copy and paste
    }
    catch {
        Add-Content $LOG_PATH "`nERROR on {$DATE} - Issue with a connection to the ShareFile. During our initial cut and paste of sharefile:{$fromPath} and pasting in the staging temp directory at:{$destPath}. Must cancel all processing.";
        exit; 
    }

    # Cleanup - remove the PSProvider
    Remove-PSDrive sfdrive    
}

# Lets take a backup shot of the folder structure and files of a specific directory ($dirToBackup). We can handle two types of backing-up structures - 
# affiliate named or admin folders. If we are backing up affiliates name (first iteration) we do not have a previous folder path (i.e. a folder already created with the
# current date and time - $pathOfPreviousFolder), and so we must create one. The second iteration we have a path where we have already stored the affiliates named folders and so we are going to 
# save the administrative folders structures in the same place as the named folders.
# Argument: $dirToBackup - Path to the directory we are backing up.
# Argument: $backupDestinationPath - Path where we are dumping this backup.
function takeBackupSnapshot($dirToBackup, $backupDestinationPath) 
{   
    $newFolder = "${backupDestinationPath}\${date}";
    
    # Create the new folder.
    try {        
        New-Item -ItemType Directory -Path $newFolder | Out-Null; # Out-Null = supress output from New-Item
    } 
    catch {
        Add-Content $LOG_PATH "`nERROR on {$DATE} - Creating backup folder for : {$newFolder}";
    }

    # Needed so that the script doesn't copy the $newFolder itself. 
    # This will allow it to only copy the contents of $dirToBackup
    $dirToBackup = $dirToBackup;
    
    # Copy all the files and their folders into this new folder we created or folder path we passed in as an argument.
    try {
        Copy-Item $dirToBackup $newFolder -Recurse;
    } 
    catch {
        Add-Content $LOG_PATH "`nERROR on {$DATE} - Moving our backup: {$dirToBackup} to: {$newFolder}"; 
    }      
}


# We remove the folder Structure of a folder (so all the affiliates named or administrative folders from the temporary staging folder)
# Argument $pathToClean - is the source, the folder where all the affiliates folders are.
# Argument $destination - is the destination we are dumping the affiliate files into, whether administrative (director of affiliates) or ASync (Client Records)
function removeLocalFolderStructureAndMove($pathToClean, $destination) 
{
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
                #Add-Content $LOG_PATH "`nERROR Creating backup from: {$dirToBackup} to: {$backupDestinationPath} on {$date}"; #$A = Get-Date; Add-Content c:\scripts\*.log $A 
                Add-Content $LOG_PATH "`nERROR {$DATE} - Removing local folder structure and moving files over for path arguments started as: FROM - {$pathToClean} TO - {$destination} ;;;; which resolves to being FROM - {$currentFilePath} TO -  {$newFilePath}"; #Adjusted on March 24 2016, I was getting messages for errors like: ERROR Creating backup from: {} to: {}


            }
            
        }
    }
    if ($pathToClean) {
        Remove-Item $pathToClean -Recurse;
    }
    
}


# Make sure we return a unique file name.
# Argument $filePath - the file and it's path, we will be appending randomized digits to its name if the name is not unique.
function getUniqueFileName($filePath) 
{
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
function recreateAffiliateFolders($parentFolderId, $isAdmin) 
{
    # Grab the pool of clients.
    $sfUsers = Send-SfRequest -Client $sfClient -Entity Accounts/Clients;

    # Lets set a value as a placeholder incase we have to log.
    if ($isAdmin) {
        $folderOwner = "Administrative";
    }
    else {
        $folderOwner = "Affiliate";                  
    }
    
    # Iterate over each user and make their folder, if they have 'companyName' in their company field.
    foreach ($sfUserId in $sfUsers) {
        
        $sfUser = Send-SfRequest -Client $sfClient -Entity Users -Id $sfUserId.Id -Expand Security # Need more details on the user, so we are expanding on the security.
                
        $company = $sfUser.Company.ToLower();        

        if ($company -match 'company_name') { #regEX
            
            $firstName = $sfUser.FirstName;
            $lastName = $sfUser.LastName;
            $lastFirst = $lastName + ", " + $firstName;
            $clientDocsNamingConvention = " Client Docs";
            $adminDocsNamingConvention = " Admin Docs";
                      
            # Make affiliate or adminstrative folders.
            if ($isAdmin) {
                $folderInfo ='{
                    "Name":"'+ $lastFirst + $adminDocsNamingConvention +'", 
                    "Description":"This is your administrative folder. Put all administrative documentation in here."
                }';
            
            }
            else {                
                $folderInfo ='{
                    "Name":"'+$lastFirst + $clientDocsNamingConvention + '", 
                    "Description":"This is your named affiliate folder. Put all consultation documentation in here."
                }';
            }
                     
            # Use folder object and create the folder.
            $folder = Send-SfRequest -Client $sfClient -Entity Items -Method POST -Id $parentFolderId -Navigation Folder -BodyText $folderInfo
            
            # issue with creating folder.
            if (!$folder) {                 
                Add-Content $LOG_PATH "`nERROR {$DATE} -Could not create the {$folderOwner} folder for affiliate {$lastFirst}. Probably means they already have a directory.";
            }
            # Create Access Control Object and send a Post request to the folder with a navigation to Access Controls.
            else {               
                
                $userPrincipal = New-Object ShareFile.Api.Models.Principal
                $AccessControlEntry = New-Object ShareFile.Api.Models.AccessControl
        
                $userPrincipal.Email = $sfUser.Username;
                $AccessControlEntry.Principal = $userPrincipal;
                $AccessControlEntry.CanDownload = $true;
                $AccessControlEntry.CanUpload = $true;
                $AccessControlEntry.CanDelete = $false;
                $AccessControlEntry.CanView = $true;
                Send-SfRequest -Client $sfClient -Method POST -Entity Items -Navigation AccessControls -Id $folder.Id -Body $AccessControlEntry
            }         
        }    
    }
} 





#################################################### MAIN #######################################################################



# FILESHARE - Grab All affiliate folders then store them into $tempPath location.
getFilesFromShareFile $FILESHARE_AFFILIATE_FOLDER_PATH $DOWNLOAD_TEMP_PATH;



# LOCAL - Backup all Affiliate folders.
$tempPathAfterDownload = $DOWNLOAD_TEMP_PATH + $LOCAL_AFFILIATES; # We have to append the name of the folder we pulled this from on fileshare, because the structure we pulled down is in this sub folder now.

takeBackupSnapshot $tempPathAfterDownload $DOWNLOAD_BACKUP_PATH ; # not an admin backup so we pass false

removeLocalFolderStructureAndMove $tempPathAfterDownload $DOWNLOAD_PROCESSING; # LOCAL - Remove the sub folder structure and move the files into the Processing folder for Client Records.

recreateAffiliateFolders $AFFILIATE_FOLDER $false; # FILESHARE - Recreate the affiliate's named folders.



### Affiliates Administrative folder scraping.
getFilesFromShareFile $FILESHARE_ADMINISTRATIVE_PATH $DOWNLOAD_ADMIN; # FILESHARE - Grab all Administrative folders.

$tempPathAfterDownload = $DOWNLOAD_ADMIN + $LOCAL_ADMINISTRATIVE; # LOCAL - Backup the Administrative folders.

takeBackupSnapshot $tempPathAfterDownload $DOWNLOAD_BACKUP_PATH_ADMIN; # backed up working good

removeLocalFolderStructureAndMove $tempPathAfterDownload $DOWNLOAD_ADMIN; # LOCAL - Remove the sub folder structure and move the administrative files into director of affiliates directory

recreateAffiliateFolders $ADMINISTRATIVE $true; # FILESHARE - Recreate the affiliate's named folders.
