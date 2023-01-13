param(
    [switch]$BackupAll
    )

#
# Script Variables
#
$BackupVM_List = Get-VM -Tag "Permit-Backups";                      # Tag to search for in vCenter. Set "*" to check all VM's
$Backup_Datastore = Get-Datastore -Name "HomeNAS-Cache";            # Datastore to place backups
$Backup_Location = Get-Folder -Name "Backup Machines";              # Location in vCenter to store VM topologically
$backupDatabase = @();                                              # Backup Database
$CloneDate = Get-Date -Format "yyyyMMdd-hhmmss";                    # Timestamp for comments and names of backups

#
# Import and Set Certification Actions
#
Get-Module -ListAvailable PowerCLI* | Import-Module
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -confirm:$False

# Do not use this line with user name and password in production enviroments.
# By Removing the User and Password variables the script will prompt for cred.
Connect-VIServer -Server "0.0.0.0" -User "user@domain.local" -Password "SomeP@ssw0rd" -Force

#
# Backup Process
#
Function Process-Backup($VM) {
# Create Snapshot Name
    $SnapshotName = "$($VM.Name) Snapshot - $($CloneDate)";
    $BackupName = "$($CloneDate) - $($VM.Name) Backup";
    Write-host "Starting VM Backup of the Following VM:" $VM.Name;

    Write-Host "Creating snapshot of $($VM.Name): " -NoNewline;
    # Create Snapshot before cloning.
    $Snapshot_Temp = New-Snapshot -VM $VM -Name $SnapshotName -Verbose:$false;
    Write-Host "Done...";

    # Cloning VM
    Write-Host "Creating backup of $($VM.Name): " -NoNewline;
    $Backup_Temp1 = New-VM -Name "$($BackupName)-Temp" -VM $VM -VMHost $VM.VMHost -Location $Backup_Location -Datastore $Backup_Datastore -LinkedClone -ReferenceSnapshot $SnapshotName;
    $Backup_Temp2 = New-VM -Name $BackupName -VM "$($BackupName)-Temp" -VMHost $VM.VMHost -Location $Backup_Location -Datastore $Backup_Datastore;
    Write-Host "Done...";

    # Remove VM from vCenter
    Write-Host "Removing backup of $($BackupName) from vCenter: " -NoNewline;
    Remove-VM -VM $Backup_Temp1 -DeletePermanently -Confirm:$false;
	  Remove-VM -VM $Backup_Temp2 -Confirm:$false;
    Write-Host "Done...";

    # Remove Snapshot after clone.
    Write-Host "Deleting snapshot of $($VM.Name): " -NoNewline;
    $nullString = ($Snapshot_Temp | Remove-Snapshot -Confirm:$false -Verbose:$false -RunAsync)
    Write-Host "Done...";

    Write-Host "Backup of $($VM.Name) complete."
    Write-Host ""
}


#
# Unattended Switches
#
if($BackupAll) {
    $BackupVM_List | Foreach-Object {
        # Process the Backup for All VM's with the marked tag.
        Process-Backup($_);
    }
    exit;
	}

#
# Function that makes menu...  Copied from stackoverflow.com (https://stackoverflow.com/questions/48691249/option-menu-in-powershell-continue-after-loop)
# Changed exit info and adjusted for menu width for the line.
#
Function MenuMaker{
    param(
        [parameter(Mandatory=$true)][String[]]$Selections,
        [switch]$IncludeExit,
        [string]$Title = $null
        )

    $Width = if($Title){$Length = $Title.Length;$Length2 = $Selections|%{$_.length}|Sort -Descending|Select -First 1;$Length2,$Length|Sort -Descending|Select -First 1}else{$Selections|%{$_.length}|Sort -Descending|Select -First 1}
    $Buffer = if(($Width*1.5) -gt 78){[math]::floor((78-$width)/2)}else{[math]::floor($width/4)}
    if($Buffer -gt 6){$Buffer = 6}
    $MaxWidth = $Buffer*2+$Width+$($Selections.count).length+2
    $Menu = @()
    $Menu += "╔"+"═"*$maxwidth+"╗"
    if($Title){
        $Menu += "║"+" "*[Math]::Floor(($maxwidth-$title.Length)/2)+$Title+" "*[Math]::Ceiling(($maxwidth-$title.Length)/2)+"║"
        $Menu += "╟"+"─"*$maxwidth+"╢"
    }
    For($i=1;$i -le $Selections.count;$i++){
        $Item = "$(if ($Selections.count -gt 9 -and $i -lt 10){" "})$i`. "
        $Menu += "║"+" "*$Buffer+$Item+$Selections[$i-1]+" "*($MaxWidth-$Buffer-$Item.Length-$Selections[$i-1].Length)+"║"
    }
    If($IncludeExit){
        $Menu += "║"+" "*$MaxWidth+"║"
        $Menu += "║"+" "*$Buffer+"-1 - Exit"+" "*($MaxWidth-$Buffer-9)+"║"
    }
    $Menu += "╚"+"═"*$maxwidth+"╝"
    $menu
}

#
# Main Script
#
While($true) {
    Cls;
    Clear-Variable -Name "Selection" -ErrorAction SilentlyContinue;
    $SelectionList = $BackupVM_List + "All";

    MenuMaker -Selections $SelectionList -Title 'Choose Virtual Machine' -IncludeExit:$true
    Write-Host ""
    if([int]$Selection = Read-Host "Choose Virtual Machine" -ErrorAction SilentlyContinue)
    {
        switch -Exact ($Selection) {
            -1 {
                exit;
            }
            {($_ -ige 1) -and ($_ -ile $BackupVM_List.Length)} {
                Cls;
                Write-Host
                Write-Host
                Write-Host
                Write-Host
                Write-Host "Backing up all $($BackupVM_List.Item($Selection-1).Name)"
                Write-Host
                Process-Backup($BackupVM_List.Item($Selection-1));
                $prompt = Read-Host -Prompt "Press enter to continue"Select
                continue;
            }
            {($BackupVM_List.Length+1)} {
                Cls;
                Write-Host
                Write-Host
                Write-Host
                Write-Host
                Write-Host "Backing up all Virtual Machines"
                Write-Host
                $BackupVM_List | Foreach-Object {
                    # Process the Backup for All VM's with the "Allow-Backups" tag.
                    Process-Backup($_);
                }
                $prompt = Read-Host -Prompt "Press enter to continue"
                continue;
            }
			            default {
                $prompt = Read-Host -Prompt "Only $($BackupVM_List.Length+1) to choose from. Press any key to try again or -1 to quit"
            }
        }
    }

}

#
# Forced exit just in-case...
#
exit;
