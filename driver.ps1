# Retrieve all VMs and display a numbered list
$vms = Get-VM
Write-Host "`nAvailable Virtual Machines:"
Write-Host "-----------------------------"
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i + 1). $($vms[$i].Name)"
}

# Prompt user to select a VM
do {
    $selection = Read-Host "`nSelect the VM number (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vmName = $vms[$index].Name
Write-Host "Selected VM: $vmName"

$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"

# Check if the script is run as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    
    # Enable integration services if needed
    Get-VM -Name $vmName | Get-VMIntegrationService | Where-Object { -not $_.Enabled } | Enable-VMIntegrationService -Verbose
    
    # Find and copy the most recent NVIDIA driver folder to a temporary path
    $localDriverFolder = (Get-ChildItem $driverPath -Recurse | 
                          Where-Object { $_.PSIsContainer -and $_.Name -match "nv_dispi.inf_amd64_*" } |
                          Sort-Object -Descending -Property LastWriteTime |
                          Select-Object -First 1).Name

    if ($localDriverFolder) {
        Write-Host "Driver folder: $localDriverFolder"
        Get-ChildItem "$driverPath$localDriverFolder" -Recurse | Where-Object { -not $_.PSIsContainer } | 
        ForEach-Object {
            $sourcePath = $_.FullName
            $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\DriverStore\\", "C:\Temp\System32\HostDriverStore\"
            Copy-VMFile -VMName $vmName -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
        }
    }

    # Copy NV* files from System32 to the destination
    Get-ChildItem $systemPath | Where-Object { $_.Name -like "NV*" } | 
    ForEach-Object {
        $sourcePath = $_.FullName
        $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\", "C:\Temp\System32\"
        Copy-VMFile -VMName $vmName -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }
    Write-Host "Success! Files are copied to C:\Temp. Please move them to the appropriate VM locations."
} else {
    Write-Host "This script requires administrative privileges."
    Write-Host "Please restart PowerShell as an administrator and run the script again."
}
