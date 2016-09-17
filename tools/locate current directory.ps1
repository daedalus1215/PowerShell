$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition


Write-Output($scriptPath);