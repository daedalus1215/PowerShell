# Creator: Laurence F. Adams III 
# Sept 16 2016


# Citrix FileShare dependency
Add-PSSnapin ShareFile


#Credential path 
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
#Profile file
$profilePath = $scriptPath + "\profile.sfps";
# oAuth token and session for a FileShare Account.                                                                                               
$sfClient = GET-SfClient -Name $profilePath;


if ($sfClient) {
    Write-Output("Connected");
} else {
    Write-Output("Not Connected");
}
