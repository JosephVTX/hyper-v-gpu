# Validación de privilegios de administrador
if (!([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script necesita ejecutarse con privilegios de Administrador. Presiona Enter para continuar y solicitar permisos..."
    Read-Host
    Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Obtener todas las VMs y mostrar lista numerada
$vms = Get-VM
Write-Host "`nMáquinas Virtuales disponibles:"
Write-Host "-----------------------------"
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i+1). $($vms[$i].Name)"
}

# Pedir al usuario que seleccione una VM
do {
    $selection = Read-Host "`nSeleccione el número de la VM (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vm = $vms[$index].Name
Write-Host "VM seleccionada: $vm`n"

$systemPath = "C:\Windows\System32\"
$driverPath = "C:\Windows\System32\DriverStore\FileRepository\"

# Habilitar servicios de integración si no están activos
Get-VM -Name $vm | Get-VMIntegrationService | Where-Object {-not($_.Enabled)} | Enable-VMIntegrationService -Verbose

# Buscar y copiar archivos a la carpeta de destino
$localDriverFolder = ""
Get-ChildItem $driverPath -recurse | Where-Object {$_.PSIsContainer -eq $true -and $_.Name -match "nv_dispi.inf_amd64_*"} | Sort-Object -Descending -Property LastWriteTime | Select-Object -First 1 |
ForEach-Object {
    if ($localDriverFolder -eq "") {
        $localDriverFolder = $_.Name                                  
    }
}
Write-Host $localDriverFolder
Get-ChildItem "$driverPath$localDriverFolder" -recurse | Where-Object {$_.PSIsContainer -eq $false} |
Foreach-Object {
    $sourcePath = $_.FullName
    $destinationPath = $sourcePath -replace "^C\:\\Windows\\System32\\DriverStore\\", "C:\Temp\System32\HostDriverStore\"
    Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
}

# Copiar archivos NV*.* en system32
Get-ChildItem $systemPath | Where-Object {$_.Name -like "NV*"} |
ForEach-Object {
    $sourcePath = $_.FullName
    $destinationPath = $sourcePath -replace "^C\:\\Windows\\System32\\", "C:\Temp\System32\"
    Copy-VMFile $vm -SourcePath $sourcePath -DestinationPath $destinationPath -Force -CreateFullPath -FileSource Host
}

Write-Host "¡Éxito! Ve a C:\Temp y copia los archivos donde se requieran dentro de la VM."
