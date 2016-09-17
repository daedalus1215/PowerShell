# Creator: Laurence F. Adams III 
# Sept 16 2016


# Citrix FileShare dependency
Add-PSSnapin ShareFile


#Credential path
$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition

#Create profile in current location.
$sfClient = New-SfClient -Name ((Join-Path D: $scriptPath) + "profile.sfps") -Account YourSubdomain # Create the profile in the form of a file, of an account. Also store a session and oAuth tokens into $sfClient.