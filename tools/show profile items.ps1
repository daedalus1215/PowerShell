# Creator: Laurence F. Adams III 
# Sept 16 2016


# Citrix FileShare dependency
Add-PSSnapin ShareFile


#Credential path 
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
#Profile file
$profilePath = $scriptPath + "\profile.sfps";
# oAuth token and session for a FileShare Account.                                                                                               
$sfLogin = GET-SfClient -Name $profilePath;


$sfItems = Send-SFRequest –Client $sfLogin –Method GET –Entity Items

Write-Output($sfItems);