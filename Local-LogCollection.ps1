<#
.SYNOPSIS
	Emulates log collection for Windows VMs available during Azure support.
	Particularly useful for providing logs to if your VM's disk is encrypted and preventing log collection by a support engineer.

.DESCRIPTION
	The script can be run directly on the "Broken" VM if it is accessible, or it can be run on a "Rescue" VM with the Broken VM's OS disk
	attached as a data disk. The results are stored $USERPROFILE\Desktop\<Hostname>_LogCollection_<datetime>.zip".


.PARAMETER DriveLetter
	Required Parameter, Drive letter of the disk (VHD), from which to pull the logs.

.PARAMETER ShowErrors
	Optional Parameter, By default it is set to false. Setting this true will display all errors thrown by PowerShell, in the console.
	It is recommended to use -Verbose instead for troubleshooting, as errors are to be expected if target log files do not exist. There
	are some log files EXPECTED to be missing as the manaifest of files below accounts for scenarios that may not be appliable to the VM.


.NOTES
	Name: Local-LogCollection.ps1
	To get help on the below script run Get-Help .\Local-LogCollection.ps1
	Author:             Clayton Fuselier
	Inspired by:        Alberto Banderas
	Acknowledgements:   Luke Steele, Craig Landis
#>


### Change Log ###
<#
v1.0
	2018-10-18

		Initially created
v1.0.1
	2018-10-19
		Code minimization
v1.0.2
	2018-10-26
		Added code for checking if the source drive is the active system drive or a data drive.
		Added code for pulling basic disk details (free/used), but currently only functions if run directly on the Broken VM and not on a Rescue VM
		Added Write-Verbose lines to facilitate use of '-Verbose', for troubleshooting purposes.
		Added the above synopsis, description, variable explanations, notes, etc.
		Added proper parameter handling (see 'param' block below changelog)
v2.0
	2018-11-01
		Complete and total revamp of the methodology for copying the target files. As a result, was able to trim the script by roughly 1000 lines!
v2.0.1
	2020-12-05
		Added PII warning and prompt to continue or stop.
v2.0.2
	2020-12-05
		Corrected some incorrect syntax.
		Corrected some inconsistent formatting in messaging.
		Cleaned up "Write-Verbose" lines to make it easier to visually scan the output and removed excessive "noise"
#>


param(
    [Parameter(mandatory=$true)]
    [String]$DriveLetter,

    [Parameter(mandatory=$false)]
    [Bool]$ShowErrors=$false
)


### Configuring Error Display
$Error.Clear()
if (-not $ShowErrors) {
    $ErrorActionPreference = 'SilentlyContinue'
}else{
    $ErrorActionPreference = 'Continue'
}


### Privacy Warning
Write-Host -ForegroundColor Red -BackgroundColor Black {
    "Warning! This script lacks any and all PII scanning capability. If there
    is any senesitive information within your logs (Azure Subscription ID etc.)
    it will NOT be scrubbed or redacted. Sharing the resulting zip file comes
    at your own risk."
}
[string]$prompt = Read-Host -Prompt "Do you want to continue? [Y] Yes or [N] No (default N)"
if (($prompt -ine "Y") -and ($prompt -ine "YES") -and ($prompt -ine "N") -and ($prompt -ine "NO") -and ($prompt -ine "")) {
    Write-Host -ForegroundColor Red -BackgroundColor Black "You have made an invalid selection. Script execution will now exit."
    exit
}
if (($prompt -ieq "N") -or ($prompt -ieq "NO") -or ($prompt -ieq "")) {
    Write-Host -ForegroundColor Red -BackgroundColor Black "Script execution will now exit."
    exit
}


### Checking DriveLetter
$DriveLetter = $DriveLetter.ToLower()
$drvpath = $DriveLetter+":\"
$drvtest = Test-Path -Path $drvpath
if(-not ($drvtest)){
    Write-Host -ForegroundColor Red -BackgroundColor Black "The drive ($drvpath) does not exist! Script execution will now stop."
    exit
}
Write-Verbose "INFO: Source drive is $DriveLetter"


### Is the Active System or Data Disk
$sys = $env:SystemDrive.ToLower()
if($sys.Contains($DriveLetter)){
    $localsys = 1
    Write-Verbose "INFO: Script is running on the ACTIVE system drive."
}else{
    $localsys = 0
    Write-Verbose "INFO: Script is NOT running on the active system drive."
}


### Prep Work
$datetime = Get-Date -UFormat "%Y%m%d%H%M%S%Z"
$pcname = Get-ChildItem -Path env:ComputerName
$file = $pcname.Value+"_LogCollection_$datetime"
$DeviceFolder = "$env:USERPROFILE\Desktop\$file\device_0"
New-Item -ItemType Directory -Path $DeviceFolder | Out-Null
if(-not (Test-Path -Path $DeviceFolder)){
    Write-Host -ForegroundColor Red -BackgroundColor Black "The destination path ($DeviceFolder) could not be created! Try running the script as Administrator. Sript execution will now stop."
    exit
}else{
	Write-Verbose "INFO: Created primary destination folder created at $DeviceFolder."
}


### Start Logging
Start-Transcript -Path $DeviceFolder\..\results.txt | Write-Verbose


### Copy/Export Registry
$dest = "$DeviceFolder\Windows\System32\config"
New-Item -ItemType Directory -Path $dest | Out-Null
Write-Verbose "INFO: Created destination folder for Registry at $dest."

Write-Verbose "Copying SOFTWARE Registry Hive"
if($localsys){
    $regsoft = reg save HKLM\SOFTWARE $dest\SOFTWARE
}else{
    Copy-Item -Path $DriveLetter":\Windows\System32\config\SOFTWARE" -Destination $dest
}

Write-Verbose "Copying SYSTEM Registry Hive"
if($localsys){
    $regsys = reg save HKLM\SYSTEM $dest\SYSTEM
}else{
    Copy-Item -Path $DriveLetter":\Windows\System32\config\SYSTEM" -Destination $dest
}

Write-Verbose "INFO: Creating array of logs to collect..."
### Event Viewer Logs
$logs = @()
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\System.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Application.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-ServiceFabric%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-ServiceFabric%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-ServiceFabric-Lease%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-ServiceFabric-Lease%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Windows Azure.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-CAPI2%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-Kernel-PnPConfig%4Configuration.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-Kernel-PnP%4Configuration.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-NdisImPlatform%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-NetworkLocationWizard%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-NetworkProfile%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-NetworkProvider%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-NlaSvc%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-RemoteDesktopServices-RdpCoreTS%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-RemoteDesktopServices-RdpCoreTS%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-RemoteDesktopServices-RemoteDesktopSessionManager%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-RemoteDesktopServices-SessionServices%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-Resource-Exhaustion-Detector%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-SmbClient%4Connectivity.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-SMBClient%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-SMBServer%4Connectivity.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-SMBServer%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-ServerManager%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TCPIP%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-LocalSessionManager%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-LocalSessionManager%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-PnPDevices%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-PnPDevices%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-RDPClient%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-RemoteConnectionManager%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-RemoteConnectionManager%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-SessionBroker-Client%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-TerminalServices-SessionBroker-Client%4Admin.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-UserPnp%4DeviceInstall.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-Windows Firewall With Advanced Security%4ConnectionSecurity.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-Windows Firewall With Advanced Security%4Firewall.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-WindowsUpdateClient%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-WindowsAzure-Diagnostics%4GuestAgent.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-WindowsAzure-Diagnostics%4Heartbeat.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-WindowsAzure-Diagnostics%4Runtime.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-WindowsAzure-Diagnostics%4Bootstrapper.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-WindowsAzure-Status%4GuestAgent.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-WindowsAzure-Status%4Plugins.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\MicrosoftAzureRecoveryServices-Replication.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Security.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Setup.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-DSC%4Operational.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-BitLocker%4BitLocker Management.evtx"
$logs += $DriveLetter+":\Windows\System32\winevt\Logs\Microsoft-Windows-BitLocker-DrivePreparationTool%4Operational.evtx"
### AzureData
$logs += $DriveLetter+":\AzureData\CustomData.bin"
### Windows Setup
$logs += $DriveLetter+":\Windows\Setup\State\State.ini"
### Panther
$logs += $DriveLetter+":\Windows\Panther\WaSetup.xml"
$logs += $DriveLetter+":\Windows\Panther\WaSetup.log"
$logs += $DriveLetter+":\Windows\Panther\unattend.xml"
$logs += $DriveLetter+":\Windows\Panther\setupact.log"
$logs += $DriveLetter+":\Windows\Panther\setuperr.log"
$logs += $DriveLetter+":\Windows\Panther\UnattendGC\setupact.log"
$logs += $DriveLetter+":\Windows\Panther\FastCleanup\setupact.log"
### Sysprep
$logs += $DriveLetter+":\Windows\System32\Sysprep\ActionFiles\Generalize.xml"
$logs += $DriveLetter+":\Windows\System32\Sysprep\ActionFiles\Specialize.xml"
$logs += $DriveLetter+":\Windows\System32\Sysprep\ActionFiles\Respecialize.xml"
$logs += $DriveLetter+":\Windows\System32\Sysprep\Panther\setupact.log"
$logs += $DriveLetter+":\Windows\System32\Sysprep\Panther\setuperr.log"
$logs += $DriveLetter+":\Windows\System32\Sysprep\Panther\IE\setupact.log"
$logs += $DriveLetter+":\Windows\System32\Sysprep\Panther\IE\setuperr.log"
$logs += $DriveLetter+":\Windows\System32\Sysprep\Sysprep_succeeded.tag"
### Inf
$logs += $DriveLetter+":\Windows\Inf\netcfg*.*etl"
$logs += $DriveLetter+":\Windows\Inf\setupapi.dev.log"
### Windows Debug
$logs += $DriveLetter+":\Windows\debug\netlogon.log"
$logs += $DriveLetter+":\Windows\debug\NetSetup.LOG"
$logs += $DriveLetter+":\Windows\debug\mrt.log"
$logs += $DriveLetter+":\Windows\debug\DCPROMO.LOG"
$logs += $DriveLetter+":\Windows\debug\dcpromoui.log"
$logs += $DriveLetter+":\Windows\debug\PASSWD.LOG"
### Windows Azure Logs/Settings
$logs += $DriveLetter+":\WindowsAzure\Logs\Telemetry.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\TransparentInstaller.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\WaAppAgent.log"
$logs += $DriveLetter+":\WindowsAzure\config\*.xml"
$logs += $DriveLetter+":\WindowsAzure\Logs\AggregateStatus\aggregatestatus*.json"
$logs += $DriveLetter+":\WindowsAzure\Logs\AppAgentRuntime.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\MonitoringAgent.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\*\*\CommandExecution.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\*\*\Install.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\*\*\Update.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\*\*\Heartbeat.log"
$logs += $DriveLetter+":\Packages\Plugins\*\*\config.txt"
$logs += $DriveLetter+":\Packages\Plugins\*\*\HandlerEnvironment.json"
$logs += $DriveLetter+":\Packages\Plugins\*\*\HandlerManifest.json"
$logs += $DriveLetter+":\Packages\Plugins\*\*\RuntimeSettings\*.settings"
$logs += $DriveLetter+":\Packages\Plugins\*\*\Status\*.status"
$logs += $DriveLetter+":\Packages\Plugins\*\*\Status\HeartBeat.Json"
$logs += $DriveLetter+":\Packages\Plugins\*\*\PackageInformation.txt"
### Windows Azure Plugin Logs
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\*\Configuration\Checkpoint.txt"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\MaConfig.xml"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\*\Configuration\MonAgentHost.*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\DiagnosticsPlugin.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\DiagnosticsPluginLauncher.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.RecoveryServices.VMSnapshot\*\IaaSBcdrExtension*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Security.IaaSAntimalware\*\AntimalwareConfig.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.Security.Monitoring\*\AsmExtension.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\FabricMSIInstall*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\InfrastructureManifest.xml"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\TempClusterManifest.xml"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\VCRuntimeInstall*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Compute.BGInfo\*\BGInfo*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Compute.JsonADDomainExtension\*\ADDomainExtension.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Compute.VMAccessAgent\*\JsonVMAccessExtension.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.EnterpriseCloud.Monitoring.MicrosoftMonitoringAgent\*\0.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\*\DSCLOG*.json"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\*\DscExtensionHandler*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Symantec.SymantecEndpointProtection\*\sepManagedAzure.txt"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\TrendMicro.DeepSecurity.TrendMicroDSA\*\*.log"
### Packages Configurations
$logs += $DriveLetter+":\Packages\Plugins\ESET.FileSecurity\*\agent_version.txt"
$logs += $DriveLetter+":\Packages\Plugins\ESET.FileSecurity\*\extension_version.txt"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\AnalyzerConfigTemplate.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\*.config"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\Logs\*DiagnosticsPlugin*.log"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\schema\wad*.json"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Diagnostics.IaaSDiagnostics\*\StatusMonitor\ApplicationInsightsPackagesVersion.json"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.RecoveryServices.VMSnapshot\*\SeqNumber.txt"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Microsoft.WindowsAzure.Storage.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\AsmExtensionMonitoringConfig*.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\ASM.Azure.OSBaseline.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\AsmExtensionSecurityPackStartupConfig.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\AsmScan.log"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\AsmScannerConfiguration.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\Azure.Common.scm.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\SecurityPackStartup.log"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\Extensions\AzureSecurityPack\SecurityScanLoggerManifest.man"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\AgentStandardEvents.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\AgentStandardEventsMin.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\AgentStandardExtensions.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\AntiMalwareEvents.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\MonitoringEwsEvents.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\MonitoringEwsEventsCore.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\MonitoringEwsRootEvents.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\MonitoringStandardEvents.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\MonitoringStandardEvents2.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\MonitoringStandardEvents3.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\SecurityStandardEvents.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\SecurityStandardEvents2.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\initconfig\*\Standard\SecurityStandardEvents3.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\Monitoring\agent\MonAgent-Pkg-Manifest.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\MonitoringAgentCertThumbprints.txt"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.Security.Monitoring\*\MonitoringAgentScheduledService.txt"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\InstallUtil.InstallLog"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\Service\current.config"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\Service\InfrastructureManifest.template.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\Service\ServiceFabricNodeBootstrapAgent.InstallLog"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Azure.ServiceFabric.ServiceFabricNode\*\Service\ServiceFabricNodeBootstrapAgent.InstallState"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Compute.BGInfo\*\BGInfo.def.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Compute.BGInfo\*\PluginManifest.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Compute.BGInfo\*\config.bgi"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Compute.BGInfo\*\emptyConfig.bgi"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCWork\*.dsc"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCWork\*.log"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCWork\*.dpx"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCVersion.xml"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCWork\HotfixInstallInProgress.dsc"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.Powershell.DSC\*\DSCWork\PreInstallDone.dsc"
$logs += $DriveLetter+":\Packages\Plugins\Microsoft.SqlServer.Management.SqlIaaSAgent\*\PackageDefinition.xml"
### Additional WindowsAzure Plugin Logs
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.NetworkWatcher.Edp.NetworkWatcherAgentWindows\*\*.txt"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.NetworkWatcher.Edp.NetworkWatcherAgentWindows\*\*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.NetworkWatcher.NetworkWatcherAgentWindows\*\*.txt"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Azure.NetworkWatcher.NetworkWatcherAgentWindows\*\*.log"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.ManagedIdentity.ManagedIdentityExtensionForWindows\*\RuntimeSettings\*.xml"
$logs += $DriveLetter+":\WindowsAzure\GuestAgent*\CommonAgentConfig.config"
$logs += $DriveLetter+":\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\*\*.log"
Write-Verbose "INFO: Array created."

### Copying Logs
$logs | ForEach-Object{
    if(Test-Path -Path $_){
        $items = Get-Item -Path $_

        $items | ForEach-Object{
            $dir = $_.Directory.FullName.Split('\')
            $dest = $DeviceFolder
            $i=1
            while ($i -lt ($dir.Count)){
                $dest = "$dest\"+$dir[$i]
                $i++
            }

            New-Item -ItemType Directory -Path $dest | Out-Null
            Copy-Item -Path $_ -Destination $dest -Force
            Write-Verbose "Copied $_"
        }
    }else{
        Write-Verbose "File does not exist. Skipping $_"
    }
}


### diskinfo.txt
if($localsys){
    Write-Verbose "Generating diskinfo.txt"
    $diskinfo = get-WmiObject win32_logicaldisk
    $diskinfo > "$DeviceFolder\..\diskinfo.txt"
}else{
    Write-Verbose "INFO: $drvpath is not the active system. Skipping diskinfo.txt"
}

Write-Verbose "Log collection complete."


### Stop Logging
Stop-Transcript | Write-Verbose


### Wait to allow files to close
Write-Verbose "INFO: Waiting 5 seconds for open handles to close..."
Start-Sleep -Seconds 5


### Zip Contents
Write-Verbose "Creating archive $file.zip"
Compress-Archive -Path $DeviceFolder\.. -DestinationPath "$DeviceFolder\..\..\$file.zip" -CompressionLevel Optimal


### Cleanup
Remove-Item -Path "$DeviceFolder\.." -Recurse -Force
Write-Host -ForegroundColor Green "Log Collection is now complete."
Write-Host -ForegroundColor Green "'$file.zip' is saved to your Desktop."
