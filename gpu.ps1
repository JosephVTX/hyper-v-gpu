# List all VMs and allow the user to select one
$vms = Get-VM
Write-Host "Available Virtual Machines:"
Write-Host "-----------------------------"
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i+1). $($vms[$i].Name)"
}

# Prompt the user to select a VM
do {
    $selection = Read-Host "Select the VM number (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)

$vm = $vms[$index].Name
Write-Host "Selected VM: $vm"

# Remove existing GPU Partition Adapter if exists
Remove-VMGpuPartitionAdapter -VMName $vm -ErrorAction SilentlyContinue

# Add a new GPU Partition Adapter
Add-VMGpuPartitionAdapter -VMName $vm

# Configure GPU Partition Adapter settings
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionVRAM 1GB -MaxPartitionVRAM 11GB -OptimalPartitionVRAM 10GB
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionEncode 1 -MaxPartitionEncode 11 -OptimalPartitionEncode 10
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionDecode 1 -MaxPartitionDecode 11 -OptimalPartitionDecode 10
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionCompute 1 -MaxPartitionCompute 11 -OptimalPartitionCompute 10

# Set VM configuration for memory and caching
Set-VM -VMName $vm -GuestControlledCacheTypes $true -LowMemoryMappedIoSpace 1GB -HighMemoryMappedIoSpace 32GB

# Start the VM
Start-VM -Name $vm

Write-Host "VM $vm is configured and started successfully."
