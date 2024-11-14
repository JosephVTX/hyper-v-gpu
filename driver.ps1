# Check if script is run as admin
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if( -not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) ) {
    Write-Host "This PowerShell script must be run with Administrative Privileges."
    exit
}

# Obtener todas las VMs y mostrar lista numerada
$vms = Get-VM
Write-Host "Available Virtual Machines:"
Write-Host "-----------------------------"
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i+1). $($vms[$i].Name)"
}

# Pedir al usuario que seleccione una VM
do {
    $selection = Read-Host "Select the VM number (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vm = $vms[$index].Name
Write-Host "Selected VM: $vm"

$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"

# Enable guest VM privileges if necessary
Get-VM -Name $vm | Get-VMIntegrationService | ? {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

# Aggregate and copy files to DriverStore
$localDriverFolder = ""
Get-ChildItem $driverPath -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "nv_dispi.inf_amd64_*"} | Sort-Object -Descending -Property LastWriteTime | select -First 1 |
ForEach-Object {
    if ($localDriverFolder -eq "") {
        $localDriverFolder = $_.Name                                  
    }
}
Write-Host $localDriverFolder
Get-ChildItem $driverPath$localDriverFolder -recurse | Where-Object {$_.PSIsContainer -eq $false} |
Foreach-Object {
    $sourcePath = $_.FullName
    $destinationPath = $sourcePath -replace "^C\:\\Windows\\System32\\DriverStore\\","C:\Temp\System32\HostDriverStore\"
    Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
}

# Get all files related to NV*.* in system32
Get-ChildItem $systemPath  | Where-Object {$_.Name -like "NV*"} |
ForEach-Object {
    $sourcePath = $_.FullName
    $destinationPath = $sourcePath -replace "^C\:\\Windows\\System32\\","C:\Temp\System32\"
    Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
}

Write-Host "Success! Please go to C:\Temp and copy the files where they are expected within the VM."
