# vmWare vmBackups
The script takes a backup of running and non-running virtual machines that are managed by vCenter.  

# Requirements
This script needs the vmWare PowerCli module to run.

# Configuring the Script
You must update the following variables:

```
$BackupVM_List = Get-VM -Tag "Permit-Backups";
$Backup_Datastore = Get-Datastore -Name "HomeNAS-Cache";
$Backup_Location = Get-Folder -Name "Backup Machines";
```

In vCenter you must add the tag to the virtual machines you want to have this script to backup.  You can alter what tag to look for here, this is the same for the Datastore location where the backups will be placed and the "Folder" that will be used to place the new VM logically while the virtal machine is being cloned.

Also update the vCenter information in the script or remove the two argument so the script prompts for the login information.

# Running the script
## Option 1 (Shell Prompts)
./process-backups.ps1
## Option 2 (Unattended Backups)
./process-backups.ps1 -BackupAll:$true

