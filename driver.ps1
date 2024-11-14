# Retrieve all VMs and display a numbered list
$vms = Get-VM
Write-Host "`nAvailable Virtual Machines:"
Write-Host "-----------------------------"
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i+1). $($vms[$i].Name)"
}

# Prompt the user to select a VM
do {
    $selection = Read-Host "`nSelect the VM number (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vm = $vms[$index].Name
Write-Host "Selected VM: $vm`n"

# Define system paths
$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"

# Check if the script is running with admin privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # Enable any disabled integration services for the selected VM
    Get-VM -Name $vm | Get-VMIntegrationService | Where-Object { -not $_.Enabled } | Enable-VMIntegrationService -Verbose

    # Find the most recent driver folder for "nv_dispi.infamd64" and set up the local driver folder
    $localDriverFolder = ""
    $latestDriverFolder = Get-ChildItem $driverPath -Recurse | Where-Object { $_.PSIsContainer -and $_.Name -match "nv_dispi.infamd64" } | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
    if ($latestDriverFolder) {
        $localDriverFolder = $latestDriverFolder.Name
        Write-Host "Latest driver folder: $localDriverFolder"
        
        # Copy driver files to the temporary directory on the VM
        Get-ChildItem "$driverPath$localDriverFolder" -Recurse | Where-Object { -not $_.PSIsContainer } |
        ForEach-Object {
            $sourcePath = $_.FullName
            $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\DriverStore\\", "C:\Temp\System32\HostDriverStore\"
            Copy-VMFile -VMName $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
        }
    }

    # Copy all files starting with "NV" from System32 to the VM's temp folder
    Get-ChildItem $systemPath | Where-Object { $_.Name -like "NV*" } |
    ForEach-Object {
        $sourcePath = $_.FullName
        $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\", "C:\Temp\System32\"
        Copy-VMFile -VMName $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }

    Write-Host "Success! Files are available in C:\Temp. Please move them to the appropriate directories within the VM."
} else {
    Write-Host "This PowerShell script must be run with Administrative Privileges."
}
