# Include the ShareFile snapin.
Add-PSSnapin ShareFile

# Client Profile.
$sfClient = '';

# Directory IDs.

$TEST_AFFILIATES = 'Folder-ID'; # root of our testing environment


# Create the profile to automate this process.
#$sfClient = New-SfClient -Name ((Join-Path $env:USERPROFILE "Documents") + "\YourSubdomain.sfps") -Account YourSubdomain

# Use the previously created profile to run this script.
$sfClient = Get-SfClient -Name ((Join-Path $env:USERPROFILE "Documents") + "\YourSubdomain.sfps"); 

# Grab our test affiliate folder.
#$folders = Send-SfRequest -Client $sfClient -Method GET -Entity Items -Id $TEST_AFFILIATES -Expand Children                          # Grab all the children of a specific folder - Test folder
#$folders = Send-SfRequest -Client $sfClient -Method GET -Entity Items AllShared -Expand Children;                                    # Grab all the children of the Root Citrix FileShare folder 


# Iterate over the folders
foreach ($folder in $folders.Children) {
    Write-Output($folder); # print each child out
}