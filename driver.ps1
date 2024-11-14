# Get all VMs and display numbered list
$vms = Get-VM
Write-Host "`nAvailable Virtual Machines:"
Write-Host "--------------------------"
$vms | ForEach-Object -Begin {$i = 1} -Process {
    Write-Host "$i. $($_.Name)"
    $i++
}

# Ask user to select a VM
do {
    $selection = Read-Host "`nSelect VM number (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vm = $vms[$index].Name
Write-Host "Selected VM: $vm`n"

# Define paths
$systemPath = "C:\Windows\System32"
$driverPath = Join-Path $systemPath "DriverStore\FileRepository"
$tempBasePath = "C:\Temp"

# Check for admin privileges
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Error: This script requires administrative privileges." -ForegroundColor Red
    exit 1
}

try {
    # Enable required VM integration services
    Get-VM -Name $vm | Get-VMIntegrationService | 
        Where-Object { -not $_.Enabled } | 
        Enable-VMIntegrationService -Verbose

    # Find latest NVIDIA driver folder
    $localDriverFolder = Get-ChildItem $driverPath -Directory |
        Where-Object { $_.Name -match "nv_dispi\.inf_amd64_.*" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty Name

    if (-not $localDriverFolder) {
        Write-Host "Error: No NVIDIA driver folder found." -ForegroundColor Yellow
        exit 1
    }

    Write-Host "Found driver folder: $localDriverFolder" -ForegroundColor Green

    # Copy driver files
    $driverFiles = Get-ChildItem (Join-Path $driverPath $localDriverFolder) -Recurse -File
    foreach ($file in $driverFiles) {
        $destinationPath = $file.FullName.Replace(
            "C:\Windows\System32\DriverStore\",
            "C:\Temp\System32\HostDriverStore\"
        )
        Copy-VMFile $vm -SourcePath $file.FullName -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }

    # Copy NVIDIA-related files from System32
    Get-ChildItem $systemPath -File -Filter "NV*" | ForEach-Object {
        $destinationPath = $_.FullName.Replace(
            "C:\Windows\System32\",
            "C:\Temp\System32\"
        )
        Copy-VMFile $vm -SourcePath $_.FullName -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }

    Write-Host "Success! Please copy the files from C:\Temp in the VM to their final locations." -ForegroundColor Green
}
catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
