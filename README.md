# PowerShell
Script to automate a backup and deliver paperwork to appropriate locations

Needed to be able to automate a backup process for Citrix FileShare.

We had clients that upload two types of files into a Citrix Fileshare in order to be processed by two different departments on our side. I created a sound directory structure to automate this process. Each client has two folders (Named folders and Administrative folders). I found that if you give a client permission to a folder, then they will see that folder in their own instance of fileshare when they log on. So we created a folder for Named folders (folders their the client's name on it) and one administrative folders. Then we create an administrative folder for each client, and put it in the administrative folders directory - did the same for the named folders directory and each clients named folder.

So I created a script that went in and cut / paste the entire Citrix FileShare structures (all folders in the named folders directory and the administrative folders directory), and stores them in a temporary folder, locally. (1) We then backup, (2) cut and paste the files into the appropriate destinations (one of two folders), while making sure there is no name collision - if there is any, we randomize a 0-9 digit and append it to the end of the name, and check again for another collision, if not move the file.

The script then goes back to FileShare. This time we grab a pool of all clients that have been created in the system, make sure they belong to a particular 'Company' and have logged in ('isConfirmed'), then make them a folder based off the naming convention (lastname, firstname) and finally give the appropriate permissions to the generated folder. We do this for their second type of paperwork as well. 

The reason we create the folders at the end of the script and destroy them from fileshare at the beginning of the script serves two purposes. 1. The person who creates the clients profiles doesnt have to create the new client folders in the right places, because it gets done at the end of the script - every night. 2. We also clean up after clients who leave. When a client leaves and leaves the system we will grab their daily files, back it all up, and not generate them new folders. 
