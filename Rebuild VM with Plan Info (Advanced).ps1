### Deployment Options
$usePlan = 0			# 0=No Plan Info, 1=Use Plan Info
$useAvSet = 0			# 0=No Availability Set, 1=Use Availability Set


### Required Variables
$vmName = "myVM"
$vmSize = "Standard_D2s_v4"
$rgName = "myResourceGroup"
$nicName = "myVMnic123"
$osDiskId = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroup/providers/Microsoft.Compute/disks/myVM_OsDisk_1"


### Optional Variables
# Requires $useAvSet to be "1"
$avSetName = ""

# Requires $usePlan to be "1"
$planPublisherName = ""    
$planProductName = ""
$planName = ""

# Requires $useAvSet to be "1"
$createAvSet = 0		# 0=The Availability Set already exists, 1=Create the Availability Set

# If you have data disks to add, fill them in below in the appropriate section and then uncomment the lines.
# If you have multiple data disks, duplicate the lines increment the $lun variable for each copy.



###########################
## Begin Building the VM ##
###########################


### Create VM Configuration
if ($useAvSet) {
    if ($createAvSet) {
        $disk = Get-AzDisk -ResourceGroupName ($osDiskId.Split("/"))[4] -Name ($osDiskId.Split("/"))[8]
        New-AzAvailabilitySet -ResourceGroupName $rgName -Name $avSetName -Location $disk.Location
    }
    $avSetId = Get-AzAvailabilitySet -Name $avSetName
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetID $avSetId.Id
} else {
    $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
}


### Set the Marketplace plan information
if ($usePlan) {
    $vmConfig = Set-AzVMPlan -VM $vmConfig -Publisher $planPublisherName -Product $planProductName -Name $planName
}


### Get the NIC
$nic = Get-AzNetworkInterface -ResourceGroupName $rgName -Name $nicName
$vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.id


### Set OS Disk
$vmConfig = Set-AzVMOSDisk -VM $vmConfig -ManagedDiskId $osDiskId -Name ($osDiskId.Split("/"))[-1] -CreateOption Attach -Windows # Can be -Linux or -Windows


### Add Data Disk
#$lun = 0
#$diskCaching = "None"    # Can be "None", "ReadOnly", or "ReadWrite"
#$dataDiskId = "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/myResourceGroup/providers/Microsoft.Compute/disks/myVM_DataDisk_1"
#$dataDiskSize = (Get-AzDisk -ResourceGroupName ($dataDiskId.Split("/"))[4] -DiskName ($dataDiskId.Split("/"))[-1]).DiskSizeGB
#$vmConfig = Add-AzVMDataDisk -VM $vmConfig -ManagedDiskId $dataDiskId -Name ($dataDiskId.split("/"))[-1] -Caching $diskCaching -DiskSizeInGB $dataDiskSize -Lun $lun -CreateOption Attach


### Deploy VM Configuration
New-AzVM -VM $vmConfig
