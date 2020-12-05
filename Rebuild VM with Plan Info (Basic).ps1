# Create VM Configuration
$vmName = "myVM"
$vmSize = "Standard_D2s_v4"
$rgName = "myResourceGroup"
$vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize


# Set the Marketplace plan information
$publisherName = ""
$productName = ""
$planName = ""
$vmConfig = Set-AzVMPlan -VM $vmConfig -Publisher $publisherName -Product $productName -Name $planName


# Get the NIC
$nicName = "myVMnic123"
$nic = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nicName
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.id


# Set OS Disk
$osDiskResourceID = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroup/providers/Microsoft.Compute/disks/myVM_OsDisk_1"
$osDiskName = "myVM_OsDisk_1"
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -ManagedDiskId $osDiskResourceID -Name $osDiskName -CreateOption Attach -Windows # Can be -Linux or -Windows


# Add Data Disk
#$dataDiskId = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroup/providers/Microsoft.Compute/disks/myVM_DataDisk_1"
#$dataDiskName = "myVM_DataDisk_1"
#$lun = 0
#$vmConfig = Add-AzVMDataDisk -VM $vmConfig -ManagedDiskId $dataDiskId -Name $dataDiskName -Caching None -DiskSizeInGB 1023 -Lun $lun -CreateOption Attach

# Deploy VM Configuration
New-AzVM -VM $vmConfig
