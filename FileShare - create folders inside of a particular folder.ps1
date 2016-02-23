Add-PSSnapin ShareFile

# Client Profile.
$sfClient = '';

# Directory IDs.
# FileShare directories
$TEST_AFFILIATES = 'folder-id'; # root of our testing environment
$TEST_STAGING_AFFILIATES = 'folder-id'; # directory we are staging out affiliate structure.
$TEST_ADMINISTRATIVE = 'folder-id'; # directory we are grabbing the administrative folders from


# Create the profile to automate this process.
#$sfClient = New-SfClient -Name ((Join-Path $env:USERPROFILE "Documents") + "\YourSubdomain.sfps") -Account YourSubdomain

# Use the previously created profile to run this script.
$sfClient = Get-SfClient -Name ((Join-Path $env:USERPROFILE "Documents") + "\YourSubdomain.sfps");

$sfUsers = Send-SfRequest -Client $sfClient -Entity Accounts/Clients;


foreach ($sfUser in $sfUsers) {  
    Write-Output($sfUser);  
    Write-Output("Client name: " + $sfUser.Name);
    Write-Output("Client id: " + $sfUser.Id);
    
    # Create their folder inside of the $TEST_STAGINGIN_AFFILIATES
    # Declare/Instantiate the required variable to create the Administrative directory.
    $folderInfo ='{
        "Name":"'+$sfUser.Name+' Administrative", 
        "Description":"All documents go in here, make sure you put Administrative documents inside the Administrative Directory."
    }';

    # Creates the folder inside of test - swap for affiliates
    $folder = Send-SfRequest -Client $sfClient -Entity Items -Method POST -Id $TEST_ADMINISTRATIVE -Navigation Folder -BodyText $folderInfo

}
