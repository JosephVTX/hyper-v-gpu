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

$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"
$tempPath = "C:\Temp\System32\HostDriverStore\"

# Check if script is running with admin privileges
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # Get the latest NVIDIA driver folder (specific to nv_dispi.infamd64)
    $latestDriverFolder = (Get-ChildItem $driverPath -Recurse | 
                            Where-Object { $_.PSIsContainer -and $_.Name -match "nv_dispi.infamd64" } | 
                            Sort-Object LastWriteTime -Descending | 
                            Select-Object -First 1).Name

    # Copy NVIDIA driver files (e.g., .inf, .sys, .dll, .cat) from the driver folder to the VM, only those starting with "NV"
    Get-ChildItem "$driverPath$latestDriverFolder" -Recurse | 
    Where-Object { -not $_.PSIsContainer -and $_.Name -like "NV*" } | 
    ForEach-Object {
        $sourcePath = $_.FullName
        $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\DriverStore\\", $tempPath
        Copy-VMFile -VMName $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }

    # Copy NVIDIA related files (e.g., NV*.dll, NV*.sys) from System32 to the VM, only those starting with "NV"
    Get-ChildItem $systemPath -Filter "NV*" | 
    ForEach-Object {
        $sourcePath = $_.FullName
        $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\", "C:\Temp\System32\"
        Copy-VMFile -VMName $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }

    Write-Host "Success! NVIDIA driver files have been copied to C:\Temp. Please transfer them within the VM as required."
} else {
    Write-Host "This PowerShell script must be run with administrative privileges for proper functionality."
}
