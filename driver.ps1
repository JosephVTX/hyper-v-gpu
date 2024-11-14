# Get VMs and display numbered list
$vms = Get-VM
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i+1). $($vms[$i].Name)"
}

# Get user selection
do {
    $selection = Read-Host "Select VM"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vm = $vms[$index].Name
$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"

if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    # Enable VM integration services if needed
    Get-VM -Name $vm | Get-VMIntegrationService | ? {-not($_.Enabled)} | Enable-VMIntegrationService
    
    # Find and copy driver files
    $localDriverFolder = ""
    Get-ChildItem $driverPath -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "nv_dispi.inf_amd64_*"} | Sort-Object -Descending -Property LastWriteTime | select -First 1 |
    ForEach-Object {
        if ($localDriverFolder -eq "") {
            $localDriverFolder = $_.Name
        }
    }
    
    # Copy files from driver folder
    Get-ChildItem $driverPath$localDriverFolder -recurse | Where-Object {$_.PSIsContainer -eq $false} |
    ForEach-Object {
        $sourcePath = $_.FullName
        Write-Host "Copying: $($_.Name)"
        
        # Copy to HostDriverStore
        $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\DriverStore\\", "C:\Temp\System32\HostDriverStore\"
        Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
        
        # Copy to FileRepository
        $destinationPath2 = "C:\Temp\System32\HostDriverStore\FileRepository\$localDriverFolder\" + $_.Name
        Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath2 -Force -CreateFullPath -FileSource Host
    }
    
    # Copy System32 NVIDIA files
    Get-ChildItem $systemPath | Where-Object {$_.Name -like "NV*"} |
    ForEach-Object {
        Write-Host "Copying: $($_.Name)"
        $sourcePath = $_.FullName
        $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\", "C:\Temp\System32\"
        Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
    }
} else {
    Write-Host "Run as administrator"
}
