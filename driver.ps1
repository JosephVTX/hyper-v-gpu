# Paths
$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"

# Check if script is running as Administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if ($currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    # List available VMs
    $vms = Get-VM | Select-Object -Property Name
    Write-Host "Available VMs:"
    for ($i = 0; $i -lt $vms.Count; $i++) {
        Write-Host "[$($i + 1)] $($vms[$i].Name)"
    }
    
    # Prompt to select VM by number
    $selection = Read-Host "Enter the number of the VM you want to select"
    if ($selection -match '^\d+$' -and $selection -le $vms.Count) {
        $vm = $vms[$selection - 1].Name
        Write-Host "Selected VM: $vm"
        
        # Enable integration services if needed
        Get-VM -Name $vm | Get-VMIntegrationService | Where-Object {-not $_.Enabled} | Enable-VMIntegrationService -Verbose

        # Find the latest NVidia driver folder in DriverStore
        $latestDriverFolder = Get-ChildItem $driverPath -Recurse |
            Where-Object { $_.PSIsContainer -and $_.Name -match "nv_dispi.inf_amd64_*" } |
            Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1

        if ($latestDriverFolder) {
            Write-Host "Found driver folder: $($latestDriverFolder.Name)"

            # Copy files from DriverStore to VM
            Get-ChildItem $latestDriverFolder.FullName -Recurse | Where-Object { -not $_.PSIsContainer } |
            ForEach-Object {
                $sourcePath = $_.FullName
                $destinationPath = $sourcePath -replace "^C:\Windows\System32\DriverStore\\", "C:\Temp\System32\HostDriverStore\"
                Copy-VMFile -VMName $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
            }

            # Copy NVidia-related files from System32 to VM
            Get-ChildItem $systemPath | Where-Object { $_.Name -like "NV*" } |
            ForEach-Object {
                $sourcePath = $_.FullName
                $destinationPath = $sourcePath -replace "^C:\Windows\System32\\", "C:\Temp\System32\"
                Copy-VMFile -VMName $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
            }

            Write-Host "Success! Go to C:\Temp within the VM and move the files to their expected locations."
        }
        else {
            Write-Host "No NVidia driver folder found in DriverStore."
        }
    }
    else {
        Write-Host "Invalid selection. Please run the script again and select a valid number."
    }
}
else {
    Write-Host "This PowerShell Script must be run with Administrative Privileges for it to work."
}
