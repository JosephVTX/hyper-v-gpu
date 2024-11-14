# Function to check administrative privileges
function Test-AdminPrivileges {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to display available VMs and get user selection
function Get-VMSelection {
    $vms = Get-VM
    
    Write-Host "`nAvailable Virtual Machines:"
    Write-Host "--------------------------"
    
    for ($i = 0; $i -lt $vms.Count; $i++) {
        Write-Host "$($i+1). $($vms[$i].Name)"
    }
    
    do {
        try {
            $selection = Read-Host "`nSelect VM number (1-$($vms.Count))"
            $index = [int]$selection - 1
            if ($index -lt 0 -or $index -ge $vms.Count) {
                Write-Host "Invalid selection. Please try again." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Please enter a valid number." -ForegroundColor Red
            $index = -1
        }
    } while ($index -lt 0 -or $index -ge $vms.Count)
    
    return $vms[$index].Name
}

# Function to enable VM integration services
function Enable-VMIntegrationServices {
    param ([string]$VMName)
    
    try {
        Get-VM -Name $VMName | 
        Get-VMIntegrationService | 
        Where-Object { -not($_.Enabled) } | 
        Enable-VMIntegrationService -Verbose
    }
    catch {
        Write-Host "Error enabling integration services: $_" -ForegroundColor Red
        exit 1
    }
}

# Function to copy NVIDIA drivers
function Copy-NvidiaDrivers {
    param (
        [string]$VMName,
        [string]$SystemPath = "C:\Windows\System32\",
        [string]$DriverPath = "C:\Windows\System32\DriverStore\FileRepository\"
    )
    
    try {
        # Find latest NVIDIA driver folder
        $localDriverFolder = ""
        Get-ChildItem $DriverPath -Recurse | 
            Where-Object { $_.PSIsContainer -eq $true -and $_.Name -match "nv_dispi.inf_amd64_*" } |
            Sort-Object -Descending -Property LastWriteTime | 
            Select-Object -First 1 |
            ForEach-Object {
                if ($localDriverFolder -eq "") {
                    $localDriverFolder = $_.Name
                }
            }
        
        Write-Host "Found driver folder: $localDriverFolder" -ForegroundColor Green
        
        # Copy DriverStore files
        Get-ChildItem "$DriverPath$localDriverFolder" -Recurse |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object {
                $sourcePath = $_.FullName
                # Maintain original path structure for DriverStore
                $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\DriverStore\\", "C:\Temp\System32\HostDriverStore\"
                Copy-VMFile $VMName -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
            }

        # Copy FileRepository files
        Get-ChildItem "$DriverPath$localDriverFolder" -Recurse |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object {
                $sourcePath = $_.FullName
                # Create additional copy in FileRepository
                $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\DriverStore\\FileRepository\\", "C:\Temp\System32\HostDriverStore\FileRepository\"
                Copy-VMFile $VMName -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
            }
        
        # Copy System32 NVIDIA files
        Get-ChildItem $SystemPath |
            Where-Object { $_.Name -like "NV*" } |
            ForEach-Object {
                $sourcePath = $_.FullName
                $destinationPath = $sourcePath -replace "^C:\\Windows\\System32\\", "C:\Temp\System32\"
                Copy-VMFile $VMName -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
            }
        
        Write-Host "`nFiles copied successfully!" -ForegroundColor Green
        Write-Host "Please go to C:\Temp in the VM and copy the files to their respective locations." -ForegroundColor Cyan
    }
    catch {
        Write-Host "Error copying files: $_" -ForegroundColor Red
        exit 1
    }
}

# Main script execution
if (-not (Test-AdminPrivileges)) {
    Write-Host "This script requires administrative privileges." -ForegroundColor Red
    exit 1
}

try {
    # Get VM selection from user
    $selectedVM = Get-VMSelection
    
    # Enable integration services
    Enable-VMIntegrationServices -VMName $selectedVM
    
    # Copy NVIDIA drivers
    Copy-NvidiaDrivers -VMName $selectedVM
}
catch {
    Write-Host "An unexpected error occurred: $_" -ForegroundColor Red
    exit 1
}
