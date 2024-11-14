# Retrieve a list of all virtual machines
$vms = Get-VM
Write-Host "Available Virtual Machines:"
Write-Host "-----------------------------"

# Display each VM with an index for user selection
for ($i = 0; $i -lt $vms.Count; $i++) {
    Write-Host "$($i+1). $($vms[$i].Name)"
}

# Prompt the user to select a VM from the list
do {
    $selection = Read-Host "Select the VM number (1-$($vms.Count))"
    $index = [int]$selection - 1
} while ($index -lt 0 -or $index -ge $vms.Count)  # Ensure the selection is within the valid range

# Store the selected VM's name
$vm = $vms[$index].Name
Write-Host "Selected VM: $vm"

# Check for an existing GPU Partition Adapter and remove it if found
$gpuAdapter = Get-VMGpuPartitionAdapter -VMName $vm -ErrorAction SilentlyContinue
if ($gpuAdapter) {
    Remove-VMGpuPartitionAdapter -VMName $vm
    Write-Host "Removed existing GPU Partition Adapter from $vm."
}

# Add a new GPU Partition Adapter to the VM
Add-VMGpuPartitionAdapter -VMName $vm
Write-Host "Added new GPU Partition Adapter to $vm."

# Configure GPU resource partitions (VRAM, Encode, Decode, Compute)
# Settings for VRAM
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionVRAM 1 -MaxPartitionVRAM 11 -OptimalPartitionVRAM 10

# Settings for GPU Encoding capability
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionEncode 1 -MaxPartitionEncode 11 -OptimalPartitionEncode 10

# Settings for GPU Decoding capability
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionDecode 1 -MaxPartitionDecode 11 -OptimalPartitionDecode 10

# Settings for GPU Compute capability
Set-VMGpuPartitionAdapter -VMName $vm -MinPartitionCompute 1 -MaxPartitionCompute 11 -OptimalPartitionCompute 10

# Set memory mapped I/O spaces
Set-VM -GuestControlledCacheTypes $true -VMName $vm
Set-VM -LowMemoryMappedIoSpace 1Gb -VMName $vm
Set-VM -HighMemoryMappedIoSpace 32GB -VMName $vm

# Start the virtual machine
Start-VM -Name $vm
Write-Host "VM $vm has been started with the configured GPU adapter."
